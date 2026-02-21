function gwt-ticket --description "Execute ticket autonomously with ralph-loop (Claude in devcontainer, nvim+terminal on host)"
    # Usage: gwt-ticket [issue-key] <title> <description> [options]
    #
    # Creates worktree via gwt-dev, sets up tmux window, and launches Claude
    # with ralph-loop for autonomous ticket execution.
    #
    # If issue-key is omitted (first arg doesn't match ABC-123 pattern),
    # auto-generates TASK-YYYYMMDD-HHMMSS as the key.
    #
    # Options:
    #   --max N         Max iterations (default: 20)
    #   --command C     Slash command to use (default: /ralph-wiggum:ralph-loop)
    #   --prompt-template F  File with custom prompt template
    #   --prompt-prefix P    Text to prepend to prompt
    #   --prompt-suffix S    Text to append to prompt
    #   --local         Use local Ollama model (default: qwen3-coder)
    #   --model MODEL   Use specific Ollama model (implies --local)
    #   --mount, -m     Additional mount (repeatable)
    #   --session S     Tmux session name (default: repo name)
    #   --devcon        Use devcontainer for isolation (default: local)
    #   --sub NAME      Claude subscription profile (maps to ~/.claude-NAME config dir)
    #   --system S      Ticketing system: linear or jira
    #   --help, -h      Show help

    # Check if we're in a git repository (skip for --status which works from anywhere)
    if not contains -- --status $argv
        if not git rev-parse --git-dir >/dev/null 2>&1
            echo "Error: Not in a git repository"
            return 1
        end
    end

    # Delegate to subcommands
    if test (count $argv) -gt 0
        switch $argv[1]
            case --plan
                gwtt-plan $argv[2..]
                return $status
            case --status
                gwt-status $argv[2..]
                return $status
            case --queue
                gwt-queue $argv[2..]
                return $status
        end
    end

    # Parse arguments
    set -l issue_key ""
    set -l title ""
    set -l description ""
    set -l max_iterations 20
    set -l session_name ""
    set -l ticketing_system ""
    set -l use_devcon false
    set -l mounts
    set -l show_help false
    set -l skip_next false
    set -l positional_index 0
    set -l is_auto_generated false # Track if issue key was auto-generated
    set -l slash_command "/ralph-wiggum:ralph-loop"
    set -l prompt_template ""
    set -l prompt_prefix ""
    set -l prompt_suffix ""
    set -l sub_profile ""
    set -l bridge_mode false
    set -l workflow_template ""
    set -l show_status false
    set -l status_json false
    set -l gate_type ""
    set -l gate_dep_worktree ""
    set -l no_checkpoints false
    set -l bridge_iterations ""
    set -l use_local false
    set -l local_model ""
    set -l bridge_providers ""
    set -l bridge_verbose false
    set -l bridge_model ""
    set -l bridge_timeout ""
    set -l bridge_log ""
    set -l auto_cleanup ""
    set -l rebase_merge false
    set -l convoy_id ""
    set -l molecule_id ""
    set -l town_sync true
    set -l mayor_tracked false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end

        set -l arg $argv[$i]

        switch $arg
            case --help -h
                set show_help true
            case --devcon
                set use_devcon true
            case --max
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set max_iterations $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --max requires a number"
                    return 1
                end
            case --session
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set session_name $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --session requires a name"
                    return 1
                end
            case --system
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set ticketing_system $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --system requires a value (linear or jira)"
                    return 1
                end
            case --command
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set slash_command $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --command requires a slash command (e.g., /feature-dev:feature-dev)"
                    return 1
                end
            case --prompt-template
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l template_path $argv[$next_i]
                    set -l expanded_path (eval echo $template_path)
                    if test -f "$expanded_path"
                        set prompt_template (realpath $expanded_path)
                    else
                        echo "Error: Prompt template file not found: $template_path"
                        return 1
                    end
                    set skip_next true
                else
                    echo "Error: --prompt-template requires a file path"
                    return 1
                end
            case --prompt-prefix
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set prompt_prefix $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --prompt-prefix requires text"
                    return 1
                end
            case --prompt-suffix
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set prompt_suffix $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --prompt-suffix requires text"
                    return 1
                end
            case --sub
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set sub_profile $argv[$next_i]
                    # Validate the config dir exists
                    set -l config_dir "$HOME/.claude-$sub_profile"
                    if not test -d "$config_dir"
                        echo "Error: Profile '$sub_profile' not found ($config_dir)"
                        echo "Run: claude-sub setup $sub_profile"
                        return 1
                    end
                    set skip_next true
                else
                    echo "Error: --sub requires a profile name (e.g., work, personal)"
                    return 1
                end
            case --local
                set use_local true
                if test -z "$local_model"
                    set local_model qwen3-coder
                end
            case --model
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set local_model $argv[$next_i]
                    set use_local true
                    set skip_next true
                else
                    echo "Error: --model requires a model name (e.g., qwen3-coder)"
                    return 1
                end
            case --mount -m
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l mount_path $argv[$next_i]
                    set -l expanded_path (eval echo $mount_path)
                    if test -d "$expanded_path"
                        set -a mounts (realpath $expanded_path)
                    else
                        echo "Error: Mount directory not found: $mount_path"
                        return 1
                    end
                    set skip_next true
                else
                    echo "Error: --mount requires a directory path"
                    return 1
                end
            case --template -t
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set workflow_template $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --template requires a workflow name (e.g., implement, bugfix, refactor, test)"
                    return 1
                end
            case --bridge
                set bridge_mode true
                # Optional: --bridge N sets max consensus iterations
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    if string match -qr '^[0-9]+$' $argv[$next_i]
                        set bridge_iterations $argv[$next_i]
                        set skip_next true
                    end
                end
            case --bridge-providers
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set bridge_providers $argv[$next_i]
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-providers requires a comma-separated list (e.g., gemini,codex,ollama)"
                    return 1
                end
            case --bridge-verbose
                set bridge_verbose true
                set bridge_mode true
            case --bridge-model
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set bridge_model $argv[$next_i]
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-model requires a model name"
                    return 1
                end
            case --bridge-timeout
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set bridge_timeout $argv[$next_i]
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-timeout requires seconds"
                    return 1
                end
            case --bridge-log
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set bridge_log $argv[$next_i]
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-log requires a file path"
                    return 1
                end
            case --no-checkpoints
                set no_checkpoints true
            case --auto-cleanup
                set auto_cleanup --auto-cleanup
            case --no-auto-cleanup
                set auto_cleanup --no-auto-cleanup
            case --rebase
                set rebase_merge true
            case --status
                set show_status true
            case --json
                set status_json true
            case --gate
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set gate_type $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --gate requires type (ci-pipeline, pr-review, human-input, dependency)"
                    return 1
                end
            case --gate-dep
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set gate_dep_worktree $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --gate-dep requires worktree path"
                    return 1
                end
            case --convoy
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set convoy_id $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --convoy requires a convoy ID"
                    return 1
                end
            case --molecule
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    # If next arg looks like a molecule ID (not a flag), use it
                    if not string match -q -- '-*' $argv[$next_i]
                        set molecule_id $argv[$next_i]
                        set skip_next true
                    else
                        # No ID given, will create from template
                        set molecule_id auto
                    end
                else
                    set molecule_id auto
                end
            case --town
                set town_sync true
            case --no-town
                set town_sync false
            case --mayor
                set mayor_tracked true
            case --no-mayor
                set mayor_tracked false
            case '-*'
                echo "Error: Unknown option: $arg"
                return 1
            case '*'
                # Positional arguments: issue_key, title, description
                set positional_index (math $positional_index + 1)
                switch $positional_index
                    case 1
                        set issue_key $arg
                    case 2
                        set title $arg
                    case 3
                        set description $arg
                    case '*'
                        # Append to description
                        set description "$description $arg"
                end
        end
    end

    # Show help
    if $show_help
        echo "Usage: gwt-ticket [issue-key] <title> <description> [options]"
        echo ""
        echo "Execute a ticket autonomously with ralph-loop."
        echo "Runs locally by default. Use --devcon for devcontainer isolation."
        echo ""
        echo "Arguments:"
        echo "  issue-key     Issue key (e.g., ENG-123, DEVOPS-456)"
        echo "              If omitted, uses title slug for branch/worktree names"
        echo "  title         Issue title/summary"
        echo "  description   Full issue description"
        echo ""
        echo "Options:"
        echo "  --max N              Max iterations (default: 20)"
        echo "  --command C          Slash command (default: /ralph-wiggum:ralph-loop)"
        echo "  --prompt-template F  Custom prompt template file"
        echo "  --prompt-prefix P    Text to prepend to prompt"
        echo "  --prompt-suffix S    Text to append to prompt"
        echo "  --sub NAME           Claude subscription profile (uses ~/.claude-NAME config dir)"
        echo "  --local              Use local Ollama model (default: qwen3-coder)"
        echo "  --model MODEL        Use specific Ollama model (implies --local)"
        echo "  --mount, -m          Add directory mount (repeatable)"
        echo "  --session S          Tmux session name (default: repo name)"
        echo "  --devcon             Use devcontainer for isolation (default: local)"
        echo "  --system S           Ticketing system: linear or jira"
        echo "  --bridge [N]         Enable cross-provider reasoning bridge (N=max iterations, default: 3)"
        echo "  --bridge-providers P Comma-separated provider order (codex,gemini,ollama,deepseek,claude,opencode)"
        echo "  --bridge-verbose     Verbose bridge logging to stderr"
        echo "  --bridge-model M     Model override for first provider in --bridge-providers order"
        echo "  --bridge-timeout S   Per-provider timeout in seconds (default: 120)"
        echo "  --bridge-log FILE    Log bridge reviews to file"
        echo "  --rebase             Rebase onto main before merging (re-spawns on conflict)"
        echo "  --auto-cleanup       Auto-remove worktree after successful merge (1hr grace period)"
        echo "  --no-auto-cleanup    Disable auto-cleanup (keep worktree after merge)"
        echo "  --template, -t NAME  Workflow template (implement, bugfix, refactor, test)"
        echo "  --plan NAME [specs]  Orchestrate multiple gwtt runs as a convoy (see gwtt-plan --help)"
        echo "  --status [--convoy]  Show worktree/agent status (delegates to gwt-status)"
        echo "  --queue <cmd> [...]  Manage ticket queue (delegates to gwt-queue)"
        echo "  --convoy NAME|ID     Associate ticket with a convoy (creates if name doesn't exist)"
        echo "  --molecule [ID]      Create/attach molecule workflow (auto-creates from template steps)"
        echo "  --town               Enable town-level bead sync on completion (default: on)"
        echo "  --no-town            Disable town-level bead sync"
        echo "  --mayor              Register ticket with mayor for global tracking"
        echo "  --no-mayor           Disable mayor registration"
        echo "  --gate TYPE          Create phase gate (ci-pipeline, pr-review, human-input, dependency)"
        echo "  --gate-dep PATH      Dependency worktree for --gate dependency"
        echo "  --help, -h           Show this help"
        echo ""
        echo "Examples:"
        echo "  # Standard ticket execution"
        echo "  gwt-ticket ENG-123 \"Fix auth bug\" \"Session tokens expire incorrectly\""
        echo ""
        echo "  # Use a specific Claude subscription"
        echo "  gwt-ticket ENG-123 \"Fix auth bug\" \"Details\" --sub personal"
        echo ""
        echo "  # Use feature-dev instead of ralph-loop"
        echo "  gwt-ticket ENG-123 \"Add feature\" \"Description\" --command /feature-dev:feature-dev"
        echo ""
        echo "  # Use a workflow template (implement, bugfix, refactor, test)"
        echo "  gwt-ticket ENG-123 \"Add auth\" \"OAuth2 flow\" --template implement"
        echo ""
        echo "  # Custom prompt template with variables"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --prompt-template ~/.claude/prompts/careful.md"
        echo ""
        echo "  # Run with local Ollama model (no cloud API)"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --local"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --model deepseek-coder-v2:16b"
        echo ""
        echo "  # Add instructions before/after"
        echo "  gwt-ticket ENG-123 \"Fix\" \"Desc\" --prompt-prefix \"IMPORTANT: No test changes\""
        echo ""
        echo "Prompt Template Variables:"
        echo "  {{ISSUE_KEY}}          Issue key (ENG-123)"
        echo "  {{TITLE}}              Issue title"
        echo "  {{DESCRIPTION}}        Issue description"
        echo "  {{WORKTREE_PATH}}      Path to worktree"
        echo "  {{COMPLETION_PROMISE}} Completion string (TICKET_ENG-123_COMPLETE)"
        return 0
    end

    # Validate --bridge-providers if specified
    if test -n "$bridge_providers"
        set -l known_providers codex gemini ollama deepseek claude opencode
        for p in (string split ',' -- $bridge_providers)
            if not contains -- $p $known_providers
                echo "Error: Unknown bridge provider '$p'"
                echo "Valid providers: "(string join ', ' $known_providers)
                return 1
            end
        end
    end

    # Show agent status
    if $show_status
        set -l agent_state_script ""
        for p in ~/dotfiles/scripts/agent-state.sh ~/dotfiles-gastownbeads/scripts/agent-state.sh
            if test -x "$p"
                set agent_state_script $p
                break
            end
        end
        if test -z "$agent_state_script"
            echo "Error: agent-state.sh not found"
            return 1
        end
        if $status_json
            $agent_state_script --all --json
        else
            $agent_state_script --all
        end
        return 0
    end

    # Detect if first positional arg is an issue key or title
    # Issue key pattern: ABC-123 (uppercase letters, dash, numbers)
    if test -n "$issue_key"; and not string match -qr '^[A-Z]+-[0-9]+$' "$issue_key"
        # First arg is NOT an issue key pattern - it's a title
        # Shift arguments: issue_key becomes title, title becomes description
        if test -n "$title"
            set description "$title"
        end
        set title "$issue_key"
        # Auto-generate: use TASK as marker (slug used for branch/worktree names)
        set issue_key TASK
        set is_auto_generated true
    end

    # Validate required arguments
    if test -z "$issue_key"
        echo "Error: Title required"
        echo "Usage: gwt-ticket [issue-key] <title> <description> [options]"
        return 1
    end

    if test -z "$title"
        echo "Error: Title required"
        return 1
    end

    if test -z "$description"
        set description "$title" # Use title as description if not provided
    end

    # Generate branch name
    set -l slug (string replace -a \n ' ' -- $title | string lower | string replace -ra '[^a-z0-9 ]' '' | string replace -ra ' +' ' ' | string trim | string replace -a ' ' '-' | string sub -l 30 | string replace -r -- '-+$' '')
    set -l branch_name
    if $is_auto_generated
        # Auto-generated: just use the slug (e.g., fix-auth-bug)
        set branch_name $slug
    else
        # Ticket: use just the key (e.g., plat-177)
        set -l key_lower (string lower $issue_key)
        set branch_name "$key_lower"
    end

    # Get repository info (resolve to main repo root, not worktree root)
    set -l git_common_dir (git rev-parse --git-common-dir)
    set -l repo_root (realpath "$git_common_dir/..")
    set -l repo (basename $repo_root)

    # Default session name to repo name if not explicitly set
    if test -z "$session_name"
        set session_name $repo
    end
    set -l worktree_name "$repo-$branch_name"
    set -l worktree_path "$repo_root/../$worktree_name"
    set -l instance_name (string replace -a "/" "-" $worktree_name)

    # Window name: use issue key for tickets, slug for auto-generated tasks
    set -l window_name $issue_key
    if $is_auto_generated
        set window_name $slug
    end

    echo "=== gwt-ticket ==="
    if $is_auto_generated
        echo "Task:      (autonomous, no ticket tracking)"
    else
        echo "Issue:     $issue_key"
    end
    echo "Title:     $title"
    echo "Branch:    $branch_name"
    echo "Window:    $window_name"
    echo "Worktree:  $worktree_path"
    echo "Instance:  $instance_name"
    echo "Max iter:  $max_iterations"
    echo "Session:   $session_name"
    echo "Command:   $slash_command"
    if $use_local
        echo "Model:     $local_model (local Ollama)"
    end
    if test -n "$prompt_template"
        echo "Template:  $prompt_template"
    end
    if test -n "$workflow_template"
        echo "Workflow:  $workflow_template (~/dotfiles/templates/workflows/$workflow_template.toml)"
    end
    if test -n "$sub_profile"
        echo "Sub:       $sub_profile (~/.claude-$sub_profile)"
    end
    if $bridge_mode
        set -l bridge_info "enabled (cross-provider review"
        if test -n "$bridge_iterations"
            set bridge_info "$bridge_info, max $bridge_iterations iterations"
        end
        if test -n "$bridge_providers"
            set bridge_info "$bridge_info, providers: $bridge_providers"
        end
        if test -n "$bridge_model"
            set bridge_info "$bridge_info, model: $bridge_model"
        end
        set bridge_info "$bridge_info)"
        echo "Bridge:    $bridge_info"
        if $bridge_verbose
            echo "           verbose mode on"
        end
        if test -n "$bridge_log"
            echo "           log: $bridge_log"
        end
    end
    if test -n "$prompt_prefix"
        echo "Prefix:    (custom)"
    end
    if test -n "$prompt_suffix"
        echo "Suffix:    (custom)"
    end
    if test -n "$convoy_id"
        echo "Convoy:    $convoy_id"
    end
    if test -n "$molecule_id"
        echo "Molecule:  $molecule_id"
    end
    if $town_sync
        echo "Town sync: enabled"
    end
    if $mayor_tracked
        echo "Mayor:     tracked"
    end
    if test -n "$gate_type"
        echo "Gate:      $gate_type"
        if test -n "$gate_dep_worktree"
            echo "Gate dep:  $gate_dep_worktree"
        end
    end
    echo ""

    # Check inbox for pending instructions
    set -l mail_script "$HOME/dotfiles/scripts/agent-mail.sh"
    if test -x "$mail_script"
        set -l unread_count (bash "$mail_script" count --for "$branch_name" 2>/dev/null)
        if test -n "$unread_count" -a "$unread_count" != 0
            echo "Mail: $unread_count unread message(s) for $branch_name"
            bash "$mail_script" inbox --for "$branch_name" --unread 2>/dev/null
            echo ""
        end
    end

    # Step 1: Create worktree via gwt-dev (reuses existing logic)
    echo "[1/4] Creating worktree..."
    set -l gwt_args $branch_name --no-devcon --no-cd
    if not test -d "$worktree_path"
        # Check if branch exists
        if git show-ref --verify --quiet refs/heads/$branch_name
            gwt-dev $gwt_args
        else
            gwt-dev $branch_name --new --no-devcon --no-cd
        end
        if test $status -ne 0
            echo "Error: Failed to create worktree"
            return 1
        end
    else
        echo "Worktree already exists, reusing..."
    end

    # Resolve worktree path
    set worktree_path (realpath $worktree_path)

    # Auto-init beads agent memory for worktree
    if command -q bd
        if not test -d "$worktree_path/.beads"
            pushd $worktree_path
            bd init --quiet 2>/dev/null; or true
            popd
        end
    end

    # Init agent CV for this worktree
    set -l cv_script "$HOME/dotfiles/scripts/agent-cv.sh"
    if test -x "$cv_script"
        set -l cv_args init "$worktree_path" --issue "$issue_key" --title "$title"
        if test -n "$sub_profile"
            set cv_args $cv_args --sub "$sub_profile"
        end
        if test -n "$local_model"
            set cv_args $cv_args --model "$local_model"
        end
        bash $cv_script $cv_args 2>/dev/null; or true
    end

    # Create bead for this work item
    if command -q bd
        if test -d "$worktree_path/.beads"
            pushd $worktree_path
            bd create "$issue_key" --title "$title" --body "$description" 2>/dev/null; or true
            popd
        end
    end

    # Create molecule from template steps if --molecule auto and --template given
    if test "$molecule_id" = auto -a -n "$workflow_template"
        set -l mol_script "$HOME/dotfiles/scripts/molecule.sh"
        if not test -x "$mol_script"
            set mol_script "$HOME/dotfiles-gastown/scripts/molecule.sh"
        end
        if test -x "$mol_script"
            set -l template_file "$HOME/dotfiles/templates/workflows/$workflow_template.toml"
            if test -f "$template_file"
                # Extract steps from template if present, otherwise use defaults
                set -l steps (grep '^\[\[steps\]\]' "$template_file" | wc -l | string trim)
                if test "$steps" -gt 0
                    # Has [[steps]] sections - extract step names
                    set -l step_names (grep '^name = ' "$template_file" | sed 's/^name = *//' | tr -d '"' | string join ',')
                    set molecule_id (bash "$mol_script" create "$issue_key-$workflow_template" --steps "$step_names" 2>/dev/null | grep -o 'm[0-9a-f]*')
                else
                    # No steps defined, create single-step molecule
                    set molecule_id (bash "$mol_script" create "$issue_key-$workflow_template" --steps "$workflow_template" 2>/dev/null | grep -o 'm[0-9a-f]*')
                end
            end
        end
    else if test "$molecule_id" = auto
        # --molecule without --template: create simple implement molecule
        set -l mol_script "$HOME/dotfiles/scripts/molecule.sh"
        if not test -x "$mol_script"
            set mol_script "$HOME/dotfiles-gastown/scripts/molecule.sh"
        end
        if test -x "$mol_script"
            set molecule_id (bash "$mol_script" create "$issue_key" --steps "implement,test,review" 2>/dev/null | grep -o 'm[0-9a-f]*')
        end
    end

    # Auto-enable checkpoints for worktree
    if not $no_checkpoints
        if test -f ~/dotfiles/scripts/checkpoints.sh
            pushd $worktree_path
            bash ~/dotfiles/scripts/checkpoints.sh enable 2>/dev/null; or true
            popd
        end
    end

    # Relax OpenClaw sandbox for devcontainer coding sessions (only when using devcon)
    set -l _sandbox_relaxed false
    set -l sandbox_script "$HOME/dotfiles/scripts/openclaw/sandbox-profile.sh"
    if $use_devcon
        if test -x "$sandbox_script"
            if bash "$sandbox_script" devcontainer
                set _sandbox_relaxed true
            else
                echo "Warning: sandbox profile relax failed" >&2
            end
        end
    end

    # Step 2: Ensure tmux session exists
    echo "[2/4] Setting up tmux session..."
    set -l created_new_session false
    if not tmux has-session -t $session_name 2>/dev/null
        # Create session with the ticket window as the initial window
        # This avoids an extra default window (which would show reattach-to-user-namespace)
        tmux new-session -d -s $session_name -n $window_name -c $worktree_path
        set created_new_session true
        echo "Created tmux session: $session_name"
    else
        echo "Tmux session exists: $session_name"
    end

    # Step 3: Create window for this ticket (only if session already existed)
    echo "[3/4] Creating ticket window..."

    if test "$created_new_session" = false
        # Session existed, create a new window for this ticket
        # Trailing colon forces session-level targeting — without it, tmux
        # resolves bare "dotfiles" as window main:dotfiles when a window
        # with that name exists in the current session.
        tmux new-window -t "$session_name:" -n $window_name -c $worktree_path
    end
    echo "Created window: $window_name"

    # Step 4: Build and launch Claude
    echo "[4/4] Launching Claude with $slash_command..."

    # Build the prompt
    set -l completion_promise "TICKET_"$issue_key"_COMPLETE"
    set -l base_prompt ""

    # Load workflow template if --template was specified
    if test -n "$workflow_template"
        set -l template_file "$HOME/dotfiles/templates/workflows/$workflow_template.toml"
        if not test -f "$template_file"
            echo "Error: Workflow template not found: $template_file"
            echo "Available templates:"
            for f in $HOME/dotfiles/templates/workflows/*.toml
                echo "  "(basename $f .toml)
            end
            return 1
        end

        # Parse TOML values (simple key = "value" extraction)
        set -l tpl_slash_command (grep '^slash_command = ' $template_file | head -1 | sed 's/^[^=]*= *//' | tr -d '"')
        set -l tpl_max_iterations (grep '^max_iterations = ' $template_file | head -1 | sed 's/^[^=]*= *//' | tr -d '"')

        # Extract multiline template between triple quotes
        set -l tpl_prompt (sed -n '/^template = """/,/^"""/{ /^template = """/d; /^"""/d; p; }' $template_file | string collect)

        # Override slash_command and max_iterations if template provides them
        if test -n "$tpl_slash_command"
            set slash_command $tpl_slash_command
        end
        if test -n "$tpl_max_iterations"
            set max_iterations $tpl_max_iterations
        end

        # Substitute template variables
        if test -n "$tpl_prompt"
            set base_prompt (echo $tpl_prompt \
                | string replace -a '{title}' $title \
                | string replace -a '{description}' $description \
                | string replace -a '{completion_promise}' $completion_promise \
                | string replace -a '{issue_key}' $issue_key)
        end
    end

    # If no base_prompt yet (no --template, or template had no prompt), check other sources
    if test -z "$base_prompt"
        if test -n "$prompt_template"
            # Use custom template file with variable substitution
            set base_prompt (cat $prompt_template \
                | string replace -a '{{ISSUE_KEY}}' $issue_key \
                | string replace -a '{{TITLE}}' $title \
                | string replace -a '{{DESCRIPTION}}' $description \
                | string replace -a '{{WORKTREE_PATH}}' $worktree_path \
                | string replace -a '{{COMPLETION_PROMISE}}' $completion_promise)
        else
            # Default template
            set base_prompt "Fix ticket $issue_key: $title

$description

Instructions:
1. Work in this worktree ($worktree_path)
2. Understand the existing codebase first
3. Implement the fix/feature
4. Write tests if applicable
5. Run tests to verify
6. Create atomic commits with descriptive messages
7. When complete, output $completion_promise

Do not ask questions - make reasonable decisions and iterate."
        end
    end

    # Apply prefix and suffix
    set -l prompt ""
    if test -n "$prompt_prefix"
        set prompt "$prompt_prefix

"
    end
    set prompt "$prompt$base_prompt"
    if test -n "$prompt_suffix"
        set prompt "$prompt

$prompt_suffix"
    end

    # Pre-check: verify Docker is accessible before attempting devcontainer
    if $use_devcon
        if not docker info >/dev/null 2>&1
            echo "Warning: Docker not available, falling back to local execution..."
            set use_devcon false
        end
    end

    # Ensure instance env dir exists (launch script goes here for reliable container access)
    # The instance env dir is a static mount in devcontainer.json (/devcontainer/env),
    # unlike --mount flags which don't apply to existing containers.
    set -l instance_env "$HOME/.devcontainer/instances/$instance_name/env"
    mkdir -p "$instance_env"
    mkdir -p "$HOME/.devcontainer/instances/$instance_name/work"
    mkdir -p "$worktree_path/.claude"

    # Write launch script to instance env dir (guaranteed mount inside container)
    set -l launch_script "$instance_env/launch-claude.fish"

    # Build launch script with proper escaping
    set -l escaped_prompt (string escape -- "$prompt")

    # Resolve main repo root for --add-dir (inherits CLAUDE.md into worktree sessions)
    set -l resolved_repo_root (realpath $repo_root)

    # Compute paths: container-internal when using devcon, host paths otherwise
    set -l add_dir_path $resolved_repo_root
    set -l worktree_basename (basename $worktree_path)
    set -l repo_basename (basename $resolved_repo_root)
    if $use_devcon
        set add_dir_path "/mounts/$repo_basename"
    end

    # Write script using echo to avoid printf escape issues
    # When using devcon, this script runs INSIDE the container via devcontainer exec
    echo '#!/usr/bin/env fish' >$launch_script
    echo "set -l prompt $escaped_prompt" >>$launch_script
    echo "" >>$launch_script

    # Set CLAUDE_CONFIG_DIR if subscription profile specified
    if test -n "$sub_profile"
        if $use_devcon
            echo "set -gx CLAUDE_CONFIG_DIR /home/node/.claude-$sub_profile" >>$launch_script
        else
            echo "set -gx CLAUDE_CONFIG_DIR $HOME/.claude-$sub_profile" >>$launch_script
        end
        echo "" >>$launch_script
    end

    # Set CROSS_PROVIDER_BRIDGE if bridge mode enabled
    if $bridge_mode
        echo "set -gx CROSS_PROVIDER_BRIDGE 1" >>$launch_script
        if test -n "$bridge_iterations"
            echo "set -gx CROSS_PROVIDER_MAX_ITERATIONS $bridge_iterations" >>$launch_script
        else
            echo "set -gx CROSS_PROVIDER_MAX_ITERATIONS 3" >>$launch_script
        end
        if test -n "$bridge_providers"
            echo "set -gx CROSS_PROVIDER_ORDER $bridge_providers" >>$launch_script
        end
        if $bridge_verbose
            echo "set -gx CROSS_PROVIDER_VERBOSE 1" >>$launch_script
        end
        if test -n "$bridge_model"
            # Set model for the first provider in the order
            # This is a convenience flag — for fine-grained control use env vars directly
            set -l first_provider (string split ',' -- (test -n "$bridge_providers"; and echo $bridge_providers; or echo "codex"))[1]
            switch $first_provider
                case codex
                    echo "set -gx CROSS_PROVIDER_CODEX_MODEL $bridge_model" >>$launch_script
                case gemini
                    echo "set -gx CROSS_PROVIDER_GEMINI_MODEL $bridge_model" >>$launch_script
                case ollama
                    echo "set -gx CROSS_PROVIDER_OLLAMA_MODEL $bridge_model" >>$launch_script
                case deepseek
                    echo "set -gx CROSS_PROVIDER_DEEPSEEK_MODEL $bridge_model" >>$launch_script
                case claude
                    echo "set -gx CROSS_PROVIDER_CLAUDE_MODEL $bridge_model" >>$launch_script
                case opencode
                    echo "set -gx CROSS_PROVIDER_OPENCODE_MODEL $bridge_model" >>$launch_script
            end
        end
        if test -n "$bridge_timeout"
            echo "set -gx CROSS_PROVIDER_TIMEOUT $bridge_timeout" >>$launch_script
        end
        if test -n "$bridge_log"
            echo "set -gx CROSS_PROVIDER_LOG $bridge_log" >>$launch_script
        end
        echo "" >>$launch_script
    end

    # If using local Ollama, add auto-start and env var bridge
    if $use_local
        echo '# Ensure Ollama is running (auto-start)' >>$launch_script
        echo 'if not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1' >>$launch_script
        echo '    echo "Starting Ollama..."' >>$launch_script
        echo '    if test -d "/Applications/Ollama.app"' >>$launch_script
        echo '        open -a Ollama' >>$launch_script
        echo '    else' >>$launch_script
        echo '        ollama serve &>/dev/null &' >>$launch_script
        echo '    end' >>$launch_script
        echo '    set -l attempts 0' >>$launch_script
        echo '    while not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1' >>$launch_script
        echo '        sleep 1' >>$launch_script
        echo '        set attempts (math $attempts + 1)' >>$launch_script
        echo '        if test $attempts -ge 30' >>$launch_script
        echo '            echo "Error: Ollama failed to start after 30s"' >>$launch_script
        echo '            exit 1' >>$launch_script
        echo '        end' >>$launch_script
        echo '    end' >>$launch_script
        echo '    echo "Ollama is running"' >>$launch_script
        echo end >>$launch_script
        echo '' >>$launch_script
        # Check if model is available, pull if needed
        echo '# Ensure model is available' >>$launch_script
        echo "if not ollama list 2>/dev/null | string match -q '*$local_model*'" >>$launch_script
        echo "    echo 'Pulling model $local_model...'" >>$launch_script
        echo "    ollama pull $local_model" >>$launch_script
        echo end >>$launch_script
        echo '' >>$launch_script
        # Set bridge env vars
        echo '# Bridge Claude Code to local Ollama' >>$launch_script
        echo 'set -gx ANTHROPIC_BASE_URL http://localhost:11434' >>$launch_script
        echo 'set -gx ANTHROPIC_API_KEY ollama' >>$launch_script
        echo "set -gx ANTHROPIC_MODEL $local_model" >>$launch_script
        echo '' >>$launch_script
    end

    # Build the claude command based on slash_command
    # --add-dir passes the main repo root so worktree sessions inherit its CLAUDE.md
    # ralph-loop needs special args, others just get the prompt
    # -- separates flags from positional args (prompt starts with / which --add-dir would consume)
    if string match -q '*/ralph-wiggum:ralph-loop*' $slash_command
        echo 'claude --dangerously-skip-permissions --add-dir '$add_dir_path' -- "'$slash_command' \\"$prompt\\" --max-iterations '$max_iterations' --completion-promise '$completion_promise'"' >>$launch_script
    else
        # For other commands, just pass the prompt as the argument
        echo 'claude --dangerously-skip-permissions --add-dir '$add_dir_path' -- "'$slash_command' \\"$prompt\\""' >>$launch_script
    end

    if not $use_devcon
        # Pane stays open for witness to use (conflict resolution, debugging)
        echo "" >>$launch_script
        echo "exec fish" >>$launch_script
    end
    chmod +x $launch_script

    # Detect AI guidance files to auto-open in nvim buffers
    # CLAUDE.md: AI rules/constraints. AGENTS.md: practical agent rules (editable per-worktree)
    # Priority: worktree root > .claude/ subdirectory
    set -l nvim_ai_files
    for ai_file in CLAUDE.md AGENTS.md
        if test -f "$worktree_path/$ai_file"
            set -a nvim_ai_files "$worktree_path/$ai_file"
        else if test -f "$worktree_path/.claude/$ai_file"
            set -a nvim_ai_files "$worktree_path/.claude/$ai_file"
        end
    end

    if $use_devcon
        # Build devcon up command - rebuild ensures fresh container with correct mounts
        # Without -r, devcontainer up reuses existing containers that may lack --mount binds
        set -l devcon_up_cmd "devcon claude -i $instance_name -r -E FORCE_AUTOUPDATE_PLUGINS=1 -E CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1"
        # Pass CLAUDE_CONFIG_DIR env var into container for subscription profile
        if test -n "$sub_profile"
            set devcon_up_cmd "$devcon_up_cmd -E CLAUDE_CONFIG_DIR=/home/node/.claude-$sub_profile"
        end
        if $bridge_mode
            set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_BRIDGE=1"
            if test -n "$bridge_iterations"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_MAX_ITERATIONS=$bridge_iterations"
            else
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_MAX_ITERATIONS=3"
            end
            if test -n "$bridge_providers"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_ORDER=$bridge_providers"
            end
            if $bridge_verbose
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_VERBOSE=1"
            end
            if test -n "$bridge_timeout"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_TIMEOUT=$bridge_timeout"
            end
            if test -n "$bridge_log"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_LOG=$bridge_log"
            end
        end
        set devcon_up_cmd "$devcon_up_cmd $worktree_path $resolved_repo_root"
        for mount in $mounts
            set devcon_up_cmd "$devcon_up_cmd $mount"
        end

        # Config paths for devcontainer exec
        set -l workspace "$HOME/.devcontainer/workspaces/$instance_name"
        set -l config_file "$HOME/dotfiles/devcontainer/claude-code-plugins/.devcontainer/devcontainer.json"
        set -l exec_cmd "devcontainer exec --config $config_file --workspace-folder $workspace"

        # Container-internal path for the launch script (via static devcontainer.json mount)
        set -l container_launch_script "/devcontainer/env/launch-claude.fish"

        # Host-side wrapper for the Claude pane:
        # 1. devcontainer exec runs Claude inside the container
        # 2. Post-completion runs on host after Claude exits (has git, gh, etc.)
        # 3. Falls back to interactive fish on failure so pane stays open for debugging
        set -l claude_pane_script "$worktree_path/.claude/start-claude-pane.fish"
        echo '#!/usr/bin/env fish' >$claude_pane_script
        echo "$exec_cmd fish $container_launch_script" >>$claude_pane_script
        echo "set -l claude_exit \$status" >>$claude_pane_script
        echo "" >>$claude_pane_script
        echo "if test \$claude_exit -ne 0" >>$claude_pane_script
        echo "    echo 'Claude Code devcontainer exec failed (exit '\$claude_exit')'" >>$claude_pane_script
        echo "    echo 'Container: $instance_name'" >>$claude_pane_script
        echo "    echo 'Exec cmd: $exec_cmd'" >>$claude_pane_script
        echo "    echo 'Script: $container_launch_script'" >>$claude_pane_script
        echo "    exec fish" >>$claude_pane_script
        echo end >>$claude_pane_script
        echo "" >>$claude_pane_script
        echo "# Pane stays open for witness to use (conflict resolution, debugging)" >>$claude_pane_script
        echo "exec fish" >>$claude_pane_script
        chmod +x $claude_pane_script

        # Hybrid layout: Claude in devcontainer, nvim + terminal on host
        # Only Claude Code needs isolation (runs --dangerously-skip-permissions).
        # Nvim and terminal stay on host for native config and full access.
        # ┌──────────────┬──────────────┐
        # │              │ nvim CLAUDE.md│ ← top-right (host)
        # │  Claude Code ├──────────────┤
        # │  (devcon)    │   terminal   │ ← bottom-right (host)
        # └──────────────┴──────────────┘
        # Write setup script to avoid send-keys buffer corruption from direnv output
        # Must be fish (not bash) because devcon is a fish function
        set -l setup_script "$worktree_path/.claude/setup-panes.fish"
        echo '#!/usr/bin/env fish' >$setup_script
        echo "# Auto-generated by gwt-ticket - hybrid layout (Claude in devcon, nvim+terminal on host)" >>$setup_script
        echo "$devcon_up_cmd" >>$setup_script
        echo "or begin" >>$setup_script
        echo "    echo 'Devcontainer failed to start'" >>$setup_script
        # Revert sandbox relaxation on devcontainer failure
        echo "    bash '$sandbox_script' default 2>/dev/null; or true" >>$setup_script
        echo "    exit 1" >>$setup_script
        echo end >>$setup_script
        echo "sleep 2" >>$setup_script
        echo "tmux split-window -hb -p 35 -c '$worktree_path' 'fish $claude_pane_script'" >>$setup_script
        echo "tmux last-pane" >>$setup_script
        echo "tmux split-window -v -p 30 -c '$worktree_path'" >>$setup_script
        echo "tmux select-pane -U" >>$setup_script
        if test (count $nvim_ai_files) -gt 0
            echo "nvim --cmd 'set shortmess=aoOtTIF' --cmd 'set cmdheight=10' $nvim_ai_files" >>$setup_script
        else
            echo "nvim --cmd 'set shortmess=aoOtTIF' --cmd 'set cmdheight=10'" >>$setup_script
        end
        echo "exec fish" >>$setup_script
        chmod +x $setup_script

        # Short send-keys payload immune to direnv interference
        tmux send-keys -t "$session_name:$window_name" "fish $setup_script" Enter
    else
        # Run locally with 3-pane layout:
        # ┌──────────────┬──────────────┐
        # │              │ nvim CLAUDE.md│ ← top-right (70%)
        # │  Claude Code ├──────────────┤
        # │              │   terminal   │ ← bottom-right (30%)
        # └──────────────┴──────────────┘
        # Step 1: Split horizontally - Claude on left (35%), current pane stays right
        # -hb = new pane before (left), -p 35 = 35% width
        # Note: split-window -c sets working dir for new panes; original pane keeps its cwd
        tmux split-window -t "$session_name:$window_name" -hb -p 35 -c "$worktree_path" "fish $launch_script"
        # After split: pane layout is [Claude(left,active)] [shell(right)]
        # Step 2: Switch to right pane and split it vertically for diffview + terminal
        tmux last-pane -t "$session_name:$window_name"
        tmux split-window -t "$session_name:$window_name" -v -p 30 -c "$worktree_path"
        # After split: right side has [original(top-right)] [new-terminal(bottom-right,active)]
        # Step 3: Launch nvim in the top-right pane (opens CLAUDE.md if present, go up from bottom-right)
        # Combined cd+nvim in single send-keys to avoid buffer corruption from pane resize events
        tmux select-pane -t "$session_name:$window_name" -U
        if test (count $nvim_ai_files) -gt 0
            tmux send-keys -t "$session_name:$window_name" "cd $worktree_path && nvim --cmd 'set shortmess=aoOtTIF' --cmd 'set cmdheight=10' $nvim_ai_files" Enter
        else
            tmux send-keys -t "$session_name:$window_name" "cd $worktree_path && nvim --cmd 'set shortmess=aoOtTIF' --cmd 'set cmdheight=10'" Enter
        end
    end

    # Resolve convoy name to ID before writing state file
    if test -n "$convoy_id"
        set -l convoy_script "$HOME/dotfiles/scripts/convoy.sh"
        if not test -x "$convoy_script"
            set convoy_script "$HOME/dotfiles-gastown/scripts/convoy.sh"
        end
        if test -x "$convoy_script"
            if not string match -qr '^c[0-9a-f]+$' "$convoy_id"
                set convoy_id (bash "$convoy_script" find-or-create "$convoy_id" 2>/dev/null | tail -1)
            end
        end
    end

    # Create state file for post-completion hook (directory already created for launch script)
    set -l state_file "$worktree_path/.claude/ticket-execute.local.md"

    # Determine if ticket tracking should be skipped
    set -l auto_generated_str false
    if $is_auto_generated
        set auto_generated_str true
    end

    echo "---
active: true
issue_key: \"$issue_key\"
title: \"$title\"
ticketing_system: \"$ticketing_system\"
auto_generated: $auto_generated_str
started_at: \""(date -u +%Y-%m-%dT%H:%M:%SZ)"\"
max_iterations: $max_iterations
completion_promise: \"TICKET_"$issue_key"_COMPLETE\"
worktree_path: \"$worktree_path\"
tmux_session: \"$session_name\"
tmux_window: \"$window_name\"
use_local: $use_local
local_model: \"$local_model\"
convoy_id: \"$convoy_id\"
molecule_id: \"$molecule_id\"
town_sync: $town_sync
mayor_tracked: $mayor_tracked
---

# Ticket Execution State

This file tracks the autonomous execution of ticket $issue_key.

When the ralph-loop completes (outputs the completion promise),
the post-completion hook will:
1. Create a PR
2. Transition the ticket (skipped if auto_generated)
3. Send notification

## Prompt Given

$prompt" >$state_file

    # Create phase gate if --gate was specified
    if test -n "$gate_type"
        set -l gates_script ""
        for p in ~/dotfiles/scripts/phase-gates.sh ~/dotfiles-gastownbeads/scripts/phase-gates.sh
            if test -x "$p"
                set gates_script $p
                break
            end
        end
        if test -n "$gates_script"
            set -l gate_env
            if test "$gate_type" = dependency -a -n "$gate_dep_worktree"
                set gate_env "DEP_WORKTREE=$gate_dep_worktree"
            end
            env $gate_env bash "$gates_script" create "$gate_type" "$worktree_path"
            echo "Gate created: $gate_type"
        else
            echo "Warning: phase-gates.sh not found, skipping gate creation"
        end
    end

    # Register with mayor for global tracking if --mayor specified
    if $mayor_tracked
        set -l mayor_script "$HOME/dotfiles/scripts/gwt-mayor.sh"
        if not test -x "$mayor_script"
            set mayor_script "$HOME/dotfiles-gastown/scripts/gwt-mayor.sh"
        end
        if test -x "$mayor_script"
            # Mayor logs the tracking registration
            bash "$mayor_script" log-event ticket-registered "$issue_key" "$worktree_path" 2>/dev/null; or true
        end
    end

    # Add ticket to convoy (ID already resolved from name above)
    if test -n "$convoy_id"
        set -l convoy_script "$HOME/dotfiles/scripts/convoy.sh"
        if not test -x "$convoy_script"
            set convoy_script "$HOME/dotfiles-gastown/scripts/convoy.sh"
        end
        if test -x "$convoy_script"
            bash "$convoy_script" add "$convoy_id" "$issue_key" 2>/dev/null; or true
        end
    end

    # Ensure merge-queue daemon is running (serializes merges across agents)
    set -l merge_queue_script ""
    for p in ~/dotfiles/scripts/merge-queue.sh ~/dotfiles-gastownbeads/scripts/merge-queue.sh
        if test -x "$p"
            set merge_queue_script $p
            break
        end
    end
    if test -n "$merge_queue_script"
        set -l daemon_running false
        if test -f /tmp/merge-queue-daemon.pid
            if kill -0 (cat /tmp/merge-queue-daemon.pid) 2>/dev/null
                set daemon_running true
            end
        end
        if not $daemon_running
            set -l daemon_args daemon
            if $rebase_merge
                set daemon_args $daemon_args --rebase
            end
            bash "$merge_queue_script" $daemon_args
            echo "Started merge-queue daemon"
        end
    end

    # Spawn worktree witness (per-worktree lifecycle monitor)
    set -l witness_script "$HOME/dotfiles/scripts/worktree-witness.sh"
    if not test -x "$witness_script"
        # Try gastownbeads path as fallback
        set witness_script "$HOME/dotfiles-gastownbeads/scripts/worktree-witness.sh"
    end
    if test -x "$witness_script"
        set -l witness_args "$worktree_path" --poll-interval 30 --max-retries 3
        if test -n "$auto_cleanup"
            set witness_args $witness_args $auto_cleanup
        end
        bash "$witness_script" $witness_args &
        disown
    end

    echo ""
    echo "=== Ticket execution started ==="
    echo ""
    if $is_auto_generated
        echo "Task:      $issue_key (autonomous, no ticket tracking)"
    else
        echo "Ticket:    $issue_key - $title"
    end
    echo "Title:     $title"
    echo "Worktree:  $worktree_path"
    echo "Tmux:      $session_name:$window_name"
    echo "Max iter:  $max_iterations"
    if $use_local
        echo "Model:     $local_model (local Ollama)"
    end
    echo ""
    echo "Monitoring:"
    echo "  tmux attach -t $session_name"
    echo "  tmux select-window -t $session_name:$window_name"
    echo "  worktree-witness.sh status $worktree_path"
    echo ""
    echo "Post-completion:"
    echo "  ticket-execute --complete $worktree_path"
    echo "  - PR will be created automatically"
    if not $is_auto_generated
        echo "  - Ticket will transition to Review/Done"
    end
    echo ""
    echo "State file: $state_file"
end
