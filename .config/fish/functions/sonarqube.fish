# SonarQube management wrapper
# Runs SonarQube Community Edition via Colima + Docker for local code quality analysis
#
# Server management:
#   sonarqube start        - Start SonarQube server
#   sonarqube stop         - Stop SonarQube server
#   sonarqube status       - Show status
#   sonarqube doctor       - Preflight health check
#   sonarqube restart      - Restart server
#
# Scanning:
#   sonarqube scan [dir]   - Scan a project (quality gate enforced)
#   sonarqube scan --ai    - Scan + AI analysis of findings (custom wrapper)
#   sonarqube scan --fix   - Scan + AI suggests code fixes (custom wrapper)
#   sonarqube issues [dir] - Show issues from last scan
#
# Project setup:
#   sonarqube init [dir]   - Create sonar-project.properties from template
#   sonarqube token        - Generate API token
#
# Other:
#   sonarqube logs         - Tail server logs
#   sonarqube update       - Pull latest Docker image
#   sonarqube uninstall    - Remove everything

function sonarqube --description "Manage SonarQube code quality server (Colima + Docker)"
    set -l dotfiles_root ~/dotfiles
    set -l sonarqube_script "$dotfiles_root/scripts/sonarqube/setup-sonarqube.sh"

    if not test -f "$sonarqube_script"
        echo "SonarQube script not found at $sonarqube_script"
        return 1
    end

    # Route AI-enhanced commands to Fish-level handlers
    # --ai and --fix are custom Fish wrapper flags (NOT sonar-scanner flags)
    # that pipe SonarQube API results through Claude or local LLM
    switch "$argv[1]"
        case scan
            # Check for --ai or --fix flags (custom wrapper behavior)
            set -l has_ai false
            set -l has_fix false
            set -l scan_args
            for arg in $argv[2..]
                switch $arg
                    case --ai
                        set has_ai true
                    case --fix
                        set has_fix true
                        set has_ai true
                    case '*'
                        set -a scan_args $arg
                end
            end

            # Run the actual scan via bash script
            bash "$sonarqube_script" scan $scan_args
            set -l scan_status $status

            if test $scan_status -ne 0
                return $scan_status
            end

            # If AI analysis requested, fetch issues from API and pipe to AI
            if test "$has_ai" = true
                sleep 3
                set -l project_dir "."
                if test (count $scan_args) -gt 0
                    set project_dir $scan_args[1]
                end
                set project_dir (realpath "$project_dir")
                set -l project_key (basename "$project_dir" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
                _sonarqube_ai_analyze "$project_key" "$has_fix"
            end

            return $scan_status

        case issues
            # Show issues from last scan with optional AI analysis
            set -l has_ai false
            set -l has_fix false
            set -l project_dir "."
            for arg in $argv[2..]
                switch $arg
                    case --ai
                        set has_ai true
                    case --fix
                        set has_fix true
                        set has_ai true
                    case '*'
                        set project_dir $arg
                end
            end
            set project_dir (realpath "$project_dir")
            set -l project_key (basename "$project_dir" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
            _sonarqube_show_issues "$project_key" "$has_ai" "$has_fix"

        case '*'
            # Pass through to bash script for all other commands
            if test (count $argv) -eq 0
                bash "$sonarqube_script" status
            else
                bash "$sonarqube_script" $argv
            end
    end
end

# Fetch and display issues from SonarQube API
function _sonarqube_show_issues
    set -l project_key $argv[1]
    set -l use_ai $argv[2]
    set -l suggest_fix $argv[3]
    set -l sonarqube_url "http://localhost:9000"

    # Build auth
    set -l token ""
    if set -q SONAR_TOKEN
        set token $SONAR_TOKEN
    else if test -f "$HOME/.config/sonarqube/token"
        set token (cat "$HOME/.config/sonarqube/token")
    end

    set -l auth_args
    if test -n "$token"
        set auth_args -H "Authorization: Bearer $token"
    end

    # Check server is reachable
    if not curl -sf "$sonarqube_url/api/system/status" >/dev/null 2>&1
        echo "SonarQube is not running. Start with: sonarqube start"
        return 1
    end

    # Fetch quality gate status
    set -l gate_json (curl -sf $auth_args "$sonarqube_url/api/qualitygates/project_status?projectKey=$project_key" 2>/dev/null)

    if test -n "$gate_json"
        set -l gate_val (echo "$gate_json" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo ""
        if test "$gate_val" = OK
            echo "Quality Gate: PASSED"
        else if test "$gate_val" = ERROR
            echo "Quality Gate: FAILED"
        else if test -n "$gate_val"
            echo "Quality Gate: $gate_val"
        end
    end

    # Fetch issues sorted by severity
    set -l issues_json (curl -sf $auth_args \
        "$sonarqube_url/api/issues/search?componentKeys=$project_key&ps=50&statuses=OPEN,CONFIRMED,REOPENED&s=SEVERITY&asc=false" \
        2>/dev/null)

    if test -z "$issues_json"
        echo "Could not fetch issues for project '$project_key'."
        echo "Has this project been scanned? Run: sonarqube scan"
        return 1
    end

    set -l total (echo "$issues_json" | grep -o '"total":[0-9]*' | cut -d: -f2)
    echo "Open Issues: $total"
    echo ""

    if test "$total" = 0
        echo "No issues found."
        return 0
    end

    # Format issues for display
    set -l formatted (echo "$issues_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for issue in data.get('issues', [])[:30]:
    sev = issue.get('severity', 'UNKNOWN')
    msg = issue.get('message', '')
    comp = issue.get('component', '').split(':')[-1]
    line = issue.get('line', '?')
    rule = issue.get('rule', '')
    itype = issue.get('type', '')
    print(f'[{sev}] {comp}:{line} - {msg} ({rule}, {itype})')
" 2>/dev/null)

    if test -n "$formatted"
        echo "$formatted"
    end

    # AI analysis (custom wrapper - uses Claude CLI or local Ollama, NOT a SonarQube feature)
    if test "$use_ai" = true
        _sonarqube_ai_analyze_issues "$formatted" "$suggest_fix"
    end

    echo ""
    echo "Full report: $sonarqube_url/dashboard?id=$project_key"
end

# AI analysis helper - pipes SonarQube findings to Claude or Ollama
function _sonarqube_ai_analyze
    set -l project_key $argv[1]
    set -l suggest_fix $argv[2]
    _sonarqube_show_issues "$project_key" true "$suggest_fix"
end

# Send formatted issues to AI for analysis
function _sonarqube_ai_analyze_issues
    set -l issues_text $argv[1]
    set -l suggest_fix $argv[2]

    if test -z "$issues_text"
        return 0
    end

    echo ""
    echo "--- AI Analysis (custom wrapper, not a SonarQube feature) ---"
    echo ""

    set -l ai_prompt
    if test "$suggest_fix" = true
        set ai_prompt "You are a code quality expert. Analyze these SonarQube findings and provide CONCRETE fixes for each issue. For each, show the specific code change needed. Be concise and actionable.

SonarQube Issues:
$issues_text"
    else
        set ai_prompt "You are a code quality expert. Summarize these SonarQube findings: group by severity, explain the most critical issues, and recommend fix priority. Be concise.

SonarQube Issues:
$issues_text"
    end

    # Try Claude Code CLI first, then local Ollama
    if command -q claude
        echo "$ai_prompt" | claude --print 2>/dev/null
    else if command -q ollama
        if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1
            set -l model (set -q LLM_DEFAULT_MODEL; and echo $LLM_DEFAULT_MODEL; or echo "llama3.1:8b")
            ollama run $model "$ai_prompt"
        else
            echo "(Ollama not running. Start with: ollama serve)"
            echo "Pipe findings manually: sonarqube issues | claude --print"
        end
    else
        echo "(No AI tool available. Install 'claude' CLI or 'ollama' for AI analysis)"
    end
end
