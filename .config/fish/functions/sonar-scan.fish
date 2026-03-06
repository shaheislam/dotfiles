# Quick SonarQube scan with optional AI-powered analysis
#
# Usage:
#   sonar-scan                     # Scan current project
#   sonar-scan ~/project           # Scan specific project
#   sonar-scan --ai                # Scan + AI analysis of findings
#   sonar-scan --ai --fix          # Scan + AI suggests fixes
#   sonar-scan --issues            # Show issues from last scan
#   sonar-scan --issues --ai       # AI-analyze existing issues

function sonar-scan --description "SonarQube scan with optional AI analysis"
    set -l sonarqube_url "http://localhost:9000"
    set -l token_file "$HOME/.config/sonarqube/token"
    set -l project_dir "."
    set -l use_ai false
    set -l show_issues false
    set -l suggest_fix false

    # Parse arguments
    set -l remaining_args
    for arg in $argv
        switch $arg
            case --ai
                set use_ai true
            case --fix
                set suggest_fix true
                set use_ai true
            case --issues
                set show_issues true
            case --help -h
                echo "Usage: sonar-scan [options] [directory]"
                echo ""
                echo "Options:"
                echo "  --ai       Pipe findings to AI for analysis"
                echo "  --fix      AI suggests concrete fixes (implies --ai)"
                echo "  --issues   Show issues from the last scan"
                echo "  -h, --help Show this help"
                echo ""
                echo "Examples:"
                echo "  sonar-scan                  # Scan current project"
                echo "  sonar-scan ~/my-project     # Scan specific project"
                echo "  sonar-scan --ai             # Scan + AI explains issues"
                echo "  sonar-scan --issues --ai    # AI-analyze last scan's issues"
                echo "  sonar-scan --fix            # Scan + AI suggests fixes"
                return 0
            case "*"
                set -a remaining_args $arg
        end
    end

    if test (count $remaining_args) -gt 0
        set project_dir $remaining_args[1]
    end

    set project_dir (realpath "$project_dir")
    set -l project_key (basename "$project_dir" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Read token
    set -l token ""
    if test -f "$token_file"
        set token (cat "$token_file")
    end

    # Check SonarQube is running
    if not curl -sf "$sonarqube_url/api/system/status" >/dev/null 2>&1
        echo "SonarQube is not running. Start with: sonarqube start"
        return 1
    end

    # If just showing issues, skip the scan
    if test "$show_issues" = true
        _sonar_show_issues "$sonarqube_url" "$token" "$project_key" "$use_ai" "$suggest_fix"
        return $status
    end

    # Run the scan
    echo "Scanning: $project_dir"
    sonarqube scan "$project_dir"
    set -l scan_status $status

    if test $scan_status -ne 0
        echo "Scan failed"
        return 1
    end

    # Wait briefly for server to process results
    sleep 3

    # Show issues and optionally analyze with AI
    _sonar_show_issues "$sonarqube_url" "$token" "$project_key" "$use_ai" "$suggest_fix"
end

# Helper: fetch and display SonarQube issues
function _sonar_show_issues
    set -l url $argv[1]
    set -l token $argv[2]
    set -l project_key $argv[3]
    set -l use_ai $argv[4]
    set -l suggest_fix $argv[5]

    # Build auth header
    set -l auth_args
    if test -n "$token"
        set auth_args -H "Authorization: Bearer $token"
    end

    # Fetch quality gate status
    set -l gate_status (curl -sf $auth_args "$url/api/qualitygates/project_status?projectKey=$project_key" 2>/dev/null)

    if test -n "$gate_status"
        set -l status_val (echo "$gate_status" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo ""
        if test "$status_val" = OK
            echo "Quality Gate: PASSED"
        else if test "$status_val" = ERROR
            echo "Quality Gate: FAILED"
        else
            echo "Quality Gate: $status_val"
        end
    end

    # Fetch issues
    set -l issues_json (curl -sf $auth_args \
        "$url/api/issues/search?componentKeys=$project_key&ps=50&statuses=OPEN,CONFIRMED,REOPENED&s=SEVERITY&asc=false" \
        2>/dev/null)

    if test -z "$issues_json"
        echo "Could not fetch issues. Is the project key correct? ($project_key)"
        return 1
    end

    set -l total (echo "$issues_json" | grep -o '"total":[0-9]*' | cut -d: -f2)
    echo "Open Issues: $total"
    echo ""

    if test "$total" = 0
        echo "No issues found - clean code!"
        return 0
    end

    # Format issues for display
    set -l formatted_issues (echo "$issues_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for issue in data.get('issues', [])[:30]:
    severity = issue.get('severity', 'UNKNOWN')
    msg = issue.get('message', '')
    component = issue.get('component', '').split(':')[-1]
    line = issue.get('line', '?')
    rule = issue.get('rule', '')
    issue_type = issue.get('type', '')
    print(f'[{severity}] {component}:{line} - {msg} ({rule}, {issue_type})')
" 2>/dev/null)

    if test -n "$formatted_issues"
        echo "$formatted_issues"
    end

    # AI analysis
    if test "$use_ai" = true
        echo ""
        echo "--- AI Analysis ---"
        echo ""

        set -l ai_prompt
        if test "$suggest_fix" = true
            set ai_prompt "You are a code quality expert. Analyze these SonarQube findings and provide CONCRETE fixes for each issue. For each issue, show the specific code change needed. Be concise and actionable.

SonarQube Issues:
$formatted_issues"
        else
            set ai_prompt "You are a code quality expert. Summarize these SonarQube findings. Group by severity, explain the most critical issues, and suggest which to fix first. Be concise.

SonarQube Issues:
$formatted_issues"
        end

        # Try Claude Code first (via pipe), then local LLM
        if command -q claude
            echo "$ai_prompt" | claude --print 2>/dev/null
        else if command -q ollama
            if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1
                set -l model (set -q LLM_DEFAULT_MODEL; and echo $LLM_DEFAULT_MODEL; or echo "llama3.1:8b")
                ollama run $model "$ai_prompt"
            else
                echo "(Ollama not running - start with: ollama serve)"
                echo ""
                echo "Raw findings printed above. Pipe to AI manually:"
                echo '  sonar-scan --issues | claude --print'
            end
        else
            echo "(No AI tool available. Install claude or ollama for AI analysis)"
            echo ""
            echo "Raw findings printed above."
        end
    end

    echo ""
    echo "Full report: $url/dashboard?id=$project_key"
end
