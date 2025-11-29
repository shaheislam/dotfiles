# FZF-powered helm completions with Alt key actions
# Supports: Release operations, Chart development, Repository management

# Toggle for FZF mode
set -g helm_use_fzf true

function helm_fzf_native --description "FZF-powered helm completion with Alt key actions"
    set -l cmd (commandline -opc)
    set -l current (commandline -ct)

    # Skip if not helm command
    if test "$cmd[1]" != helm
        return
    end

    # Handle --flag completion: when current token starts with -
    if string match -q -- '-*' $current
        set -l cmdline (string join -- ' ' $cmd)
        set -l flag_completions (complete -C"$cmdline $current" 2>/dev/null)

        if test (count $flag_completions) -gt 0
            set -l filtered_flags
            for fc in $flag_completions
                set -l flag_part (string split -- \t $fc)[1]
                if string match -q -- '-*' $flag_part
                    set -a filtered_flags $fc
                end
            end

            if test (count $filtered_flags) -eq 0
                return
            end

            if test (count $filtered_flags) -eq 1
                string split -- \t $filtered_flags[1] | head -1
                return
            end

            if test "$helm_use_fzf" = "true"
                set -l selected (printf '%s\n' $filtered_flags | fzf --ansi --height=40% --prompt="Flag: " --query="$current" \
                    --delimiter='\t' --with-nth=1,2 --tabstop=4)
                echo $selected | string split \t | head -1
            else
                printf '%s\n' $filtered_flags
            end
            return
        end
    end

    # Parse command to understand context
    set -l subcommand ""
    set -l sub_action ""
    set -l resource ""
    set -l last_arg ""
    set -l position 0
    set -l namespace ""

    for i in (seq 2 (count $cmd))
        set -l arg $cmd[$i]
        set last_arg $arg

        # Extract namespace
        if test $i -gt 2
            set -l prev $cmd[(math $i - 1)]
            if test "$prev" = "-n"; or test "$prev" = "--namespace"
                set namespace $arg
                continue
            end
        end

        # Skip flags
        if string match -q -- '-*' $arg
            continue
        end

        set position (math $position + 1)
        if test $position -eq 1
            set subcommand $arg
        else if test $position -eq 2
            set sub_action $arg
        else if test $position -eq 3
            set resource $arg
        end
    end

    # Determine what completions to show
    set -l completions
    set -l fzf_prompt "Select: "
    set -l preview_cmd ""
    set -l show_preview false
    set -l mode "release" # release, chart, repo

    # Handle flag value completions
    switch $last_arg
        case -n --namespace
            set completions (kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n')
            set fzf_prompt "Namespace: "
        case -f --values
            # File completion - let fish handle it
            return
    end

    # If we handled a flag above, show FZF
    if test (count $completions) -gt 0
        if test -n "$current"
            set -l filtered
            for c in $completions
                if string match -q -- "$current*" $c
                    set -a filtered $c
                end
            end
            set completions $filtered
        end

        if test (count $completions) -eq 0
            return
        end

        if test (count $completions) -eq 1
            echo $completions[1]
            return
        end

        if test "$helm_use_fzf" = "true"
            set -l selected (printf '%s\n' $completions | fzf --height=40% --prompt="$fzf_prompt" --query="$current")
            echo $selected
        else
            printf '%s\n' $completions
        end
        return
    end

    # Detect chart directory context
    set -l in_chart_dir false
    if test -f ./Chart.yaml
        set in_chart_dir true
    end

    # Handle subcommand-specific completions
    if test -z "$subcommand"
        # Show subcommands
        set completions install upgrade uninstall list rollback history status get template lint package dependency repo search show pull env plugin
        set fzf_prompt "Command: "
    else
        switch $subcommand
            # === RELEASE OPERATIONS ===
            case list ls
                # List doesn't need completion, but trigger release mode for inspection
                __helm_releases_fzf
                return

            case upgrade
                if test -z "$sub_action"
                    # Need release name first
                    __helm_releases_fzf_select "upgrade"
                    return
                else if test -z "$resource"
                    # Need chart path/name
                    __helm_chart_select
                    return
                end

            case uninstall delete un del
                if test -z "$sub_action"
                    __helm_releases_fzf_select "uninstall"
                    return
                end

            case rollback
                if test -z "$sub_action"
                    # Need release name
                    __helm_releases_fzf_select "rollback"
                    return
                else if test -z "$resource"
                    # Need revision number
                    __helm_revision_select $sub_action
                    return
                end

            case history hist
                if test -z "$sub_action"
                    __helm_releases_fzf_select "history"
                    return
                end

            case status
                if test -z "$sub_action"
                    __helm_releases_fzf_select "status"
                    return
                end

            case get
                if test -z "$sub_action"
                    set completions values manifest hooks notes all
                    set fzf_prompt "Get what: "
                else if test -z "$resource"
                    __helm_releases_fzf_select "get $sub_action"
                    return
                end

            case install
                if test -z "$sub_action"
                    # For install, first arg is release name (user types it)
                    # But if they want chart selection...
                    __helm_chart_select
                    return
                else if test -z "$resource"
                    __helm_chart_select
                    return
                end

            case test
                if test -z "$sub_action"
                    __helm_releases_fzf_select "test"
                    return
                end

            # === CHART DEVELOPMENT ===
            case lint
                if test "$in_chart_dir" = "true"
                    __helm_chart_dev_fzf "lint"
                    return
                end

            case template
                if test -z "$sub_action"
                    if test "$in_chart_dir" = "true"
                        __helm_chart_dev_fzf "template"
                        return
                    end
                    # Need release name then chart
                    echo "release-name"
                    return
                end

            case package
                if test "$in_chart_dir" = "true"
                    __helm_chart_dev_fzf "package"
                    return
                end

            case dependency dep
                if test -z "$sub_action"
                    set completions build list update
                    set fzf_prompt "Dependency action: "
                else if test "$in_chart_dir" = "true"
                    __helm_chart_dev_fzf "dependency $sub_action"
                    return
                end

            # === REPOSITORY OPERATIONS ===
            case repo
                if test -z "$sub_action"
                    set completions add list remove update index
                    set fzf_prompt "Repo action: "
                else
                    switch $sub_action
                        case remove rm
                            __helm_repo_fzf "remove"
                            return
                        case update
                            __helm_repo_fzf "update"
                            return
                    end
                end

            case search
                if test -z "$sub_action"
                    set completions hub repo
                    set fzf_prompt "Search where: "
                else if test "$sub_action" = "repo"
                    __helm_search_charts
                    return
                end

            case show
                if test -z "$sub_action"
                    set completions all chart readme values crds
                    set fzf_prompt "Show what: "
                else if test -z "$resource"
                    __helm_chart_select
                    return
                end

            case pull
                if test -z "$sub_action"
                    __helm_chart_select
                    return
                end

            # === PLUGIN OPERATIONS ===
            case plugin
                if test -z "$sub_action"
                    set completions install list uninstall update
                    set fzf_prompt "Plugin action: "
                end

            case '*'
                # Default: try release selection
                __helm_releases_fzf_select "$subcommand"
                return
        end
    end

    # Output completions
    if test (count $completions) -eq 0
        return
    end

    if test -n "$current"
        set -l filtered
        for c in $completions
            if string match -q -- "$current*" $c
                set -a filtered $c
            end
        end
        set completions $filtered
    end

    if test (count $completions) -eq 0
        return
    end

    if test (count $completions) -eq 1
        echo $completions[1]
        return
    end

    if test "$helm_use_fzf" = "true"
        set -l selected (printf '%s\n' $completions | fzf --height=40% --prompt="$fzf_prompt" --query="$current")
        echo $selected
    else
        printf '%s\n' $completions
    end
end

# === RELEASE MODE FUNCTIONS ===

function __helm_releases_fzf --description "Browse all releases with Alt key actions"
    set -l header_text 'Alt: 1=status 2=values 3=manifest 4=notes 5=history 6=test 7=hooks 8=rollback 9=upgrade | D=diff T=trivy X=delete S=search'

    # Get releases with error handling
    set -l releases_json (helm list --all-namespaces --output json 2>/dev/null)

    # Check if we got valid data
    if test -z "$releases_json"; or test "$releases_json" = "[]"
        echo "No releases found or cluster unreachable" >&2
        return 1
    end

    # Build alt key commands
    set -l status_cmd "helm status {2} -n {1} | bat --color=always --language=yaml --paging=always"
    set -l values_cmd "bash -c 'tmpfile=/tmp/helm-values-{2}-\$(date +%s).yaml; helm get values {2} -n {1} > \"\$tmpfile\" 2>/dev/null && nvim -R \"\$tmpfile\"; rm -f \"\$tmpfile\"'"
    set -l manifest_cmd "bash -c 'tmpfile=/tmp/helm-manifest-{2}-\$(date +%s).yaml; helm get manifest {2} -n {1} > \"\$tmpfile\" 2>/dev/null && nvim -R \"\$tmpfile\"; rm -f \"\$tmpfile\"'"
    set -l notes_cmd "helm get notes {2} -n {1} | less"
    set -l history_cmd "helm history {2} -n {1} | less"
    set -l test_cmd "helm test {2} -n {1}"
    set -l hooks_cmd "bash -c 'tmpfile=/tmp/helm-hooks-{2}-\$(date +%s).yaml; helm get hooks {2} -n {1} > \"\$tmpfile\" 2>/dev/null && nvim -R \"\$tmpfile\"; rm -f \"\$tmpfile\"'"

    # Alt+8: Interactive rollback
    set -l rollback_cmd "bash -c 'exec </dev/tty >/dev/tty 2>&1; echo \"=== Release History ===\"; helm history {2} -n {1}; echo \"\"; read -p \"Rollback to revision: \" rev; if [ -n \"\$rev\" ]; then helm rollback {2} \$rev -n {1}; fi'"

    # Alt+9: Upgrade with current values
    set -l upgrade_cmd "bash -c 'exec </dev/tty >/dev/tty 2>&1; chart=\$(helm list -n {1} -f \"^{2}\$\" -o json | jq -r \".[0].chart\" | sed \"s/-[0-9.]*\$//\"); echo \"Upgrading {2} with chart: \$chart\"; read -p \"Proceed? [y/N] \" c; if [ \"\$c\" = \"y\" ]; then helm upgrade {2} \$chart -n {1} --reuse-values; fi'"

    # Alt+D: Diff between revisions (requires helm-diff plugin)
    set -l diff_cmd "bash -c 'curr=\$(helm history {2} -n {1} -o json | jq -r \".[0].revision\"); prev=\$((curr - 1)); if [ \$prev -gt 0 ]; then tmpfile=/tmp/helm-diff-{2}-\$(date +%s).diff; helm diff revision {2} \$prev \$curr -n {1} > \"\$tmpfile\" 2>/dev/null && nvim -R \"\$tmpfile\" || echo \"helm-diff plugin not installed. Install with: helm plugin install https://github.com/databus23/helm-diff\"; rm -f \"\$tmpfile\"; else echo \"No previous revision to diff\"; fi; read -n 1'"

    # Alt+T: Trivy scan all images
    set -l trivy_cmd "bash -c 'echo \"=== Scanning images in {2} ===\"; images=\$(helm get manifest {2} -n {1} | grep -E \"image:\" | sed \"s/.*image: *//\" | tr -d \"\\\"'\\''\" | sort -u); for img in \$images; do echo \"\"; echo \">>> Scanning: \$img\"; trivy image --severity HIGH,CRITICAL \$img 2>/dev/null || echo \"trivy not installed\"; done' | less"

    # Alt+X: Delete with confirmation
    set -l delete_cmd "bash -c 'exec </dev/tty >/dev/tty 2>&1; read -p \"Delete release {2} from {1}? [y/N] \" c; if [ \"\$c\" = \"y\" ]; then helm uninstall {2} -n {1}; echo \"Release {2} deleted\"; else echo \"Cancelled\"; fi; sleep 1'"

    # Alt+S: Search chart versions
    set -l search_cmd "bash -c 'chart=\$(helm list -n {1} -f \"^{2}\$\" -o json | jq -r \".[0].chart\" | sed \"s/-[0-9.]*\$//\"); helm search repo \$chart --versions | less'"

    # Reload command
    set -l reload_cmd "helm list --all-namespaces --output json 2>/dev/null | jq -r '.[] | \"\\(.namespace)\\t\\(.name)\\t\\(.status)\\t\\(.chart)\\t\\(.revision)\"'"

    echo $releases_json | \
        jq -r '.[] | "\(.namespace)\t\(.name)\t\(.status)\t\(.chart)\t\(.revision)"' | \
    fzf --ansi --height=70% \
        --border-label '⎈ Helm Releases' \
        --header "$header_text" \
        --header-lines 0 \
        --preview 'helm status {2} -n {1} 2>/dev/null | bat --color=always --language=yaml --style=plain' \
        --preview-window='right:50%:wrap,<120(right,40%,wrap)' \
        --bind "ctrl-r:reload($reload_cmd)" \
        --bind "alt-1:execute($status_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-2:execute($values_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-3:execute($manifest_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-4:execute($notes_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-5:execute($history_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-6:execute($test_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-7:execute($hooks_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-8:execute($rollback_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-9:execute($upgrade_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-d:execute($diff_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-t:execute($trivy_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-x:execute($delete_cmd < /dev/tty > /dev/tty)+reload($reload_cmd)" \
        --bind "alt-s:execute($search_cmd < /dev/tty > /dev/tty)" \
        --bind 'tab:toggle+down,shift-tab:toggle+up,ctrl-/:toggle-preview' \
        --multi | awk -F'\t' '{print $2}'
end

function __helm_releases_fzf_select --description "Select release for a specific action"
    set -l action $argv[1]
    set -l header_text "Select release for: $action | Press ESC to cancel"

    # Get releases with error handling
    set -l releases_json (helm list --all-namespaces --output json 2>/dev/null)

    # Check if we got valid data
    if test -z "$releases_json"; or test "$releases_json" = "[]"
        echo "No releases found or cluster unreachable" >&2
        return 1
    end

    echo $releases_json | \
        jq -r '.[] | "\(.namespace)\t\(.name)\t\(.status)\t\(.chart)"' | \
    fzf --ansi --height=50% \
        --header "$header_text" \
        --preview 'helm status {2} -n {1} 2>/dev/null | bat --color=always --language=yaml --style=plain' \
        --preview-window='right:50%:wrap' | awk -F'\t' '{print $2}'
end

function __helm_revision_select --description "Select revision for rollback"
    set -l release $argv[1]

    set -l header_text "Select revision to rollback $release"

    # Get current namespace from context or use default
    set -l ns (kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
    test -z "$ns"; and set ns "default"

    # Alt+D: Diff this revision with current
    set -l diff_cmd "bash -c 'curr=\$(helm history $release -n $ns -o json | jq -r \".[0].revision\"); helm diff revision $release {} \$curr -n $ns 2>/dev/null | less || echo \"helm-diff not installed\"'"

    helm history $release -n $ns --output json 2>/dev/null | \
        jq -r '.[] | "\(.revision)\t\(.status)\t\(.description)"' | \
    fzf --ansi --height=50% \
        --header "$header_text | Alt+D: diff with current" \
        --preview "helm diff revision $release {} -n $ns 2>/dev/null | bat --color=always --language=diff --style=plain || helm get manifest $release --revision {} -n $ns 2>/dev/null | bat --color=always --language=yaml --style=plain | head -50" \
        --preview-window='right:50%:wrap' \
        --bind "alt-d:execute($diff_cmd < /dev/tty > /dev/tty)" | awk -F'\t' '{print $1}'
end

# === CHART MODE FUNCTIONS ===

function __helm_chart_select --description "Select a chart (local or from repo)"
    set -l header_text 'Charts: Local directories and repo charts | Alt+L=lint Alt+T=template Alt+V=versions'

    # Build list of charts
    set -l charts

    # Add local chart directories
    if test -f ./Chart.yaml
        set -a charts "./\t(local chart)"
    end

    # Find subdirectory charts
    for dir in (find . -maxdepth 2 -name Chart.yaml 2>/dev/null | xargs -I{} dirname {})
        set -a charts "$dir\t(local)"
    end

    # Add repo charts
    for repo in (helm repo list -o json 2>/dev/null | jq -r '.[].name')
        for chart in (helm search repo $repo/ -o json 2>/dev/null | jq -r '.[].name' | head -20)
            set -a charts "$chart\t(repo)"
        end
    end

    if test (count $charts) -eq 0
        echo "."
        return
    end

    # Alt+L: Lint chart
    set -l lint_cmd "helm lint {1} 2>&1 | less"
    # Alt+T: Template chart (uses temp file for LSP support)
    set -l template_cmd "bash -c 'tmpfile=/tmp/helm-template-\$(echo {1} | tr \"/\" \"-\")-\$(date +%s).yaml; helm template test-release {1} > \"\$tmpfile\" 2>&1 && nvim -R \"\$tmpfile\"; rm -f \"\$tmpfile\"'"
    # Alt+V: Show versions
    set -l versions_cmd "helm search repo {1} --versions 2>/dev/null | less || echo 'Local chart - no versions'"

    printf '%s\n' $charts | \
    fzf --ansi --height=50% \
        --header "$header_text" \
        --delimiter='\t' \
        --with-nth=1,2 \
        --preview 'helm show chart {1} 2>/dev/null | bat --color=always --language=yaml --style=plain || cat {1}/Chart.yaml 2>/dev/null | bat --color=always --language=yaml --style=plain' \
        --preview-window='right:50%:wrap' \
        --bind "alt-l:execute($lint_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-t:execute($template_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-v:execute($versions_cmd < /dev/tty > /dev/tty)" | awk -F'\t' '{print $1}'
end

function __helm_chart_dev_fzf --description "Chart development actions"
    set -l action $argv[1]
    set -l header_text 'Chart Dev: Alt+L=lint T=template P=package D=deps I=install(dry) S=scan V=values B=bump'

    # Read chart info
    set -l chart_name (yq -r '.name' Chart.yaml 2>/dev/null || echo "chart")
    set -l chart_version (yq -r '.version' Chart.yaml 2>/dev/null || echo "0.0.0")

    # Alt key commands
    set -l lint_cmd "helm lint . 2>&1; echo ''; echo 'Press any key...'; read -n 1"
    set -l template_cmd "bash -c 'tmpfile=/tmp/helm-template-local-\$(date +%s).yaml; helm template test-release . > \"\$tmpfile\" 2>&1 && nvim -R \"\$tmpfile\"; rm -f \"\$tmpfile\"'"
    set -l package_cmd "helm package . && echo 'Packaged successfully!' && ls -la *.tgz; read -n 1"
    set -l deps_cmd "helm dependency update . && echo 'Dependencies updated!'; read -n 1"
    set -l install_cmd "bash -c 'tmpfile=/tmp/helm-install-dry-\$(date +%s).yaml; helm install test-$chart_name . --dry-run --debug > \"\$tmpfile\" 2>&1 && nvim -R \"\$tmpfile\"; rm -f \"\$tmpfile\"'"
    set -l scan_cmd "trivy config . 2>/dev/null || echo 'trivy not installed'; read -n 1"
    set -l values_cmd "nvim values.yaml"
    set -l bump_cmd "bash -c 'curr=\$(yq -r \".version\" Chart.yaml); echo \"Current: \$curr\"; read -p \"New version: \" nv; if [ -n \"\$nv\" ]; then yq -i \".version = \\\"\$nv\\\"\" Chart.yaml; echo \"Updated to: \$nv\"; fi; read -n 1'"

    # Show chart actions
    set -l actions "Lint Chart\thelm lint .\nTemplate Chart\thelm template\nPackage Chart\thelm package .\nUpdate Dependencies\thelm dependency update\nInstall (dry-run)\thelm install --dry-run\nScan (Trivy)\ttrivy config .\nEdit values.yaml\tnvim values.yaml\nBump Version\tUpdate Chart.yaml version"

    printf "$actions" | \
    fzf --ansi --height=50% \
        --border-label "⎈ Chart: $chart_name v$chart_version" \
        --header "$header_text" \
        --delimiter='\t' \
        --with-nth=1 \
        --preview 'cat Chart.yaml 2>/dev/null | bat --color=always --language=yaml --style=plain' \
        --preview-window='right:40%:wrap' \
        --bind "alt-l:execute($lint_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-t:execute($template_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-p:execute($package_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-d:execute($deps_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-i:execute($install_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-s:execute($scan_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-v:execute($values_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-b:execute($bump_cmd < /dev/tty > /dev/tty)"

    # Just return current dir for chart path
    echo "."
end

# === REPO MODE FUNCTIONS ===

function __helm_repo_fzf --description "Repository operations with Alt key actions"
    set -l action $argv[1]
    set -l header_text 'Repos: Alt+U=update S=search X=remove A=add V=versions P=pull'

    # Get repos with error handling
    set -l repos_json (helm repo list -o json 2>/dev/null)

    # Check if we got valid data
    if test -z "$repos_json"; or test "$repos_json" = "[]"
        echo "No repositories configured. Use: helm repo add <name> <url>" >&2
        return 1
    end

    # Alt key commands
    set -l update_cmd "helm repo update {1} && echo 'Repository {1} updated!'; read -n 1"
    set -l search_cmd "bash -c 'read -p \"Search term: \" term; helm search repo {1}/\$term 2>/dev/null | less'"
    set -l remove_cmd "bash -c 'read -p \"Remove repo {1}? [y/N] \" c; if [ \"\$c\" = \"y\" ]; then helm repo remove {1}; echo \"Removed {1}\"; fi; read -n 1'"
    set -l add_cmd "bash -c 'read -p \"Repo name: \" name; read -p \"Repo URL: \" url; helm repo add \$name \$url && echo \"Added \$name\"; read -n 1'"
    set -l versions_cmd "bash -c 'read -p \"Chart name (e.g., nginx): \" chart; helm search repo {1}/\$chart --versions | less'"
    set -l pull_cmd "bash -c 'read -p \"Chart to pull (e.g., nginx): \" chart; helm pull {1}/\$chart --untar && echo \"Pulled {1}/\$chart\"; read -n 1'"

    set -l reload_cmd "helm repo list -o json 2>/dev/null | jq -r '.[] | \"\\(.name)\\t\\(.url)\"'"

    echo $repos_json | \
        jq -r '.[] | "\(.name)\t\(.url)"' | \
    fzf --ansi --height=50% \
        --border-label '⎈ Helm Repositories' \
        --header "$header_text" \
        --delimiter='\t' \
        --with-nth=1,2 \
        --preview 'helm search repo {1}/ -o json 2>/dev/null | jq -r ".[].name" | head -20' \
        --preview-window='right:40%:wrap' \
        --bind "ctrl-r:reload($reload_cmd)" \
        --bind "alt-u:execute($update_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-s:execute($search_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-x:execute($remove_cmd < /dev/tty > /dev/tty)+reload($reload_cmd)" \
        --bind "alt-a:execute($add_cmd < /dev/tty > /dev/tty)+reload($reload_cmd)" \
        --bind "alt-v:execute($versions_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-p:execute($pull_cmd < /dev/tty > /dev/tty)" | awk -F'\t' '{print $1}'
end

function __helm_search_charts --description "Search charts across all repos"
    set -l header_text 'Search Charts: Alt+V=versions P=pull I=info S=show values'

    # Get charts with error handling
    set -l charts_json (helm search repo "" -o json 2>/dev/null)

    # Check if we got valid data
    if test -z "$charts_json"; or test "$charts_json" = "[]"
        echo "No charts found. Configure repos with: helm repo add <name> <url>" >&2
        return 1
    end

    # Alt key commands
    set -l versions_cmd "helm search repo {1} --versions | less"
    set -l pull_cmd "helm pull {1} --untar && echo 'Pulled {1}'; read -n 1"
    set -l info_cmd "helm show chart {1} | bat --color=always --language=yaml --paging=always"
    set -l values_cmd "bash -c 'tmpfile=/tmp/helm-show-values-\$(echo {1} | tr \"/\" \"-\")-\$(date +%s).yaml; helm show values {1} > \"\$tmpfile\" 2>/dev/null && nvim -R \"\$tmpfile\"; rm -f \"\$tmpfile\"'"

    echo $charts_json | \
        jq -r '.[] | "\(.name)\t\(.version)\t\(.description)"' | \
    fzf --ansi --height=60% \
        --border-label '⎈ Search Helm Charts' \
        --header "$header_text" \
        --delimiter='\t' \
        --with-nth=1,2,3 \
        --preview 'helm show chart {1} 2>/dev/null | bat --color=always --language=yaml --style=plain' \
        --preview-window='right:50%:wrap' \
        --bind "alt-v:execute($versions_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-p:execute($pull_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-i:execute($info_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-s:execute($values_cmd < /dev/tty > /dev/tty)" | awk -F'\t' '{print $1}'
end

# Toggle function
function helm_toggle_fzf --description "Toggle FZF mode for helm completions"
    if test "$helm_use_fzf" = "true"
        set -g helm_use_fzf false
        echo "helm FZF completions disabled"
    else
        set -g helm_use_fzf true
        echo "helm FZF completions enabled"
    end
end
