function gwt-ticket --description "Execute ticket autonomously with ralph-loop in devcontainer"
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
    #   --no-devcon     Skip devcontainer, use local environment
    #   --system S      Ticketing system: linear or jira
    #   --help, -h      Show help

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    # Parse arguments
    set -l issue_key ""
    set -l title ""
    set -l description ""
    set -l max_iterations 20
    set -l session_name ""
    set -l ticketing_system ""
    set -l use_devcon true
    set -l mounts
    set -l show_help false
    set -l skip_next false
    set -l positional_index 0
    set -l is_auto_generated false  # Track if issue key was auto-generated
    set -l slash_command "/ralph-wiggum:ralph-loop"
    set -l prompt_template ""
    set -l prompt_prefix ""
    set -l prompt_suffix ""
    set -l use_local false
    set -l local_model ""

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end

        set -l arg $argv[$i]

        switch $arg
            case --help -h
                set show_help true
            case --no-devcon
                set use_devcon false
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
            case --local
                set use_local true
                if test -z "$local_model"
                    set local_model "qwen3-coder"
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
        echo "Execute a ticket autonomously with ralph-loop in a devcontainer."
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
        echo "  --local              Use local Ollama model (default: qwen3-coder)"
        echo "  --model MODEL        Use specific Ollama model (implies --local)"
        echo "  --mount, -m          Add directory mount (repeatable)"
        echo "  --session S          Tmux session name (default: repo name)"
        echo "  --no-devcon          Skip devcontainer, use local environment"
        echo "  --system S           Ticketing system: linear or jira"
        echo "  --help, -h           Show this help"
        echo ""
        echo "Examples:"
        echo "  # Standard ticket execution"
        echo "  gwt-ticket ENG-123 \"Fix auth bug\" \"Session tokens expire incorrectly\""
        echo ""
        echo "  # Use feature-dev instead of ralph-loop"
        echo "  gwt-ticket ENG-123 \"Add feature\" \"Description\" --command /feature-dev:feature-dev"
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
        set issue_key "TASK"
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
        set description "$title"  # Use title as description if not provided
    end

    # Generate branch name
    set -l slug (string lower $title | string replace -ra '[^a-z0-9 ]' '' | string replace -a ' ' '-' | string sub -l 30 | string replace -r -- '-+$' '')
    set -l branch_name
    if $is_auto_generated
        # Auto-generated: just use the slug (e.g., fix-auth-bug)
        set branch_name $slug
    else
        # Ticket: use key-slug (e.g., eng-123-fix-auth-bug)
        set -l key_lower (string lower $issue_key)
        set branch_name "$key_lower-$slug"
    end

    # Get repository info
    set -l repo (basename (git rev-parse --show-toplevel))
    set -l repo_root (git rev-parse --show-toplevel)

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
    if test -n "$prompt_prefix"
        echo "Prefix:    (custom)"
    end
    if test -n "$prompt_suffix"
        echo "Suffix:    (custom)"
    end
    echo ""

    # Step 1: Create worktree via gwt-dev (reuses existing logic)
    echo "[1/4] Creating worktree..."
    set -l gwt_args $branch_name --no-devcon
    if not test -d "$worktree_path"
        # Check if branch exists
        if git show-ref --verify --quiet refs/heads/$branch_name
            gwt-dev $gwt_args
        else
            gwt-dev $branch_name --new --no-devcon
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

    # Step 2: Ensure tmux session exists
    echo "[2/4] Setting up tmux session..."
    if not tmux has-session -t $session_name 2>/dev/null
        tmux new-session -d -s $session_name
        echo "Created tmux session: $session_name"
    else
        echo "Tmux session exists: $session_name"
    end

    # Step 3: Create window for this ticket
    echo "[3/4] Creating ticket window..."

    # Check if window already exists
    if tmux list-windows -t $session_name -F '#{window_name}' | grep -q "^$window_name\$"
        echo "Window $window_name already exists, selecting it..."
        tmux select-window -t "$session_name:$window_name"
    else
        tmux new-window -t $session_name -n $window_name -c $worktree_path
        echo "Created window: $window_name"
    end

    # Step 4: Build and launch Claude
    echo "[4/4] Launching Claude with $slash_command..."

    # Build the prompt
    set -l completion_promise "TICKET_"$issue_key"_COMPLETE"
    set -l base_prompt ""

    if test -n "$prompt_template"
        # Use custom template with variable substitution
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

    # Check if devcontainer exists and is requested
    set -l has_devcontainer false
    if test -d "$worktree_path/.devcontainer"; or test -f "$worktree_path/devcontainer.json"
        set has_devcontainer true
    end

    # Write launch script to avoid quoting hell with nested tmux send-keys
    set -l launch_script "$worktree_path/.claude/launch-claude.fish"
    mkdir -p "$worktree_path/.claude"

    # Build launch script with proper escaping
    set -l escaped_prompt (string escape -- "$prompt")

    # Write script using echo to avoid printf escape issues
    echo '#!/usr/bin/env fish' > $launch_script
    echo "set -l prompt $escaped_prompt" >> $launch_script
    echo "" >> $launch_script

    # If using local Ollama, add auto-start and env var bridge
    if $use_local
        echo '# Ensure Ollama is running (auto-start)' >> $launch_script
        echo 'if not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1' >> $launch_script
        echo '    echo "Starting Ollama..."' >> $launch_script
        echo '    if test -d "/Applications/Ollama.app"' >> $launch_script
        echo '        open -a Ollama' >> $launch_script
        echo '    else' >> $launch_script
        echo '        ollama serve &>/dev/null &' >> $launch_script
        echo '    end' >> $launch_script
        echo '    set -l attempts 0' >> $launch_script
        echo '    while not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1' >> $launch_script
        echo '        sleep 1' >> $launch_script
        echo '        set attempts (math $attempts + 1)' >> $launch_script
        echo '        if test $attempts -ge 30' >> $launch_script
        echo '            echo "Error: Ollama failed to start after 30s"' >> $launch_script
        echo '            exit 1' >> $launch_script
        echo '        end' >> $launch_script
        echo '    end' >> $launch_script
        echo '    echo "Ollama is running"' >> $launch_script
        echo 'end' >> $launch_script
        echo '' >> $launch_script
        # Check if model is available, pull if needed
        echo '# Ensure model is available' >> $launch_script
        echo "if not ollama list 2>/dev/null | string match -q '*$local_model*'" >> $launch_script
        echo "    echo 'Pulling model $local_model...'" >> $launch_script
        echo "    ollama pull $local_model" >> $launch_script
        echo 'end' >> $launch_script
        echo '' >> $launch_script
        # Set bridge env vars
        echo '# Bridge Claude Code to local Ollama' >> $launch_script
        echo 'set -gx ANTHROPIC_BASE_URL http://localhost:11434' >> $launch_script
        echo 'set -gx ANTHROPIC_API_KEY ollama' >> $launch_script
        echo "set -gx ANTHROPIC_MODEL $local_model" >> $launch_script
        echo '' >> $launch_script
    end

    # Build the claude command based on slash_command
    # ralph-loop needs special args, others just get the prompt
    if string match -q '*/ralph-wiggum:ralph-loop*' $slash_command
        echo 'claude --dangerously-skip-permissions "'$slash_command' \\"$prompt\\" --max-iterations '$max_iterations' --completion-promise '$completion_promise'"' >> $launch_script
    else
        # For other commands, just pass the prompt as the argument
        echo 'claude --dangerously-skip-permissions "'$slash_command' \\"$prompt\\""' >> $launch_script
    end
    chmod +x $launch_script

    if $use_devcon; and $has_devcontainer
        # Build devcon up command (start container without exec)
        set -l devcon_up_cmd "devcon claude -i $instance_name $worktree_path"
        for mount in $mounts
            set devcon_up_cmd "$devcon_up_cmd $mount"
        end

        # Config paths for devcontainer exec
        set -l workspace "$HOME/.devcontainer/workspaces/$instance_name"
        set -l config_file "$HOME/dotfiles/devcontainer/claude-code-plugins/.devcontainer/devcontainer.json"
        set -l exec_cmd "devcontainer exec --config $config_file --workspace-folder $workspace"

        # Split window: left pane for Claude, right pane for shell
        # Step 1: Start devcontainer
        tmux send-keys -t "$session_name:$window_name" "$devcon_up_cmd" Enter
        # Step 2: Wait a moment for container, then split and launch
        tmux send-keys -t "$session_name:$window_name" "sleep 2 && tmux split-window -hb -p 50 -c $worktree_path '$exec_cmd fish $launch_script' && $exec_cmd fish" Enter
    else
        if $use_devcon; and not $has_devcontainer
            echo "No .devcontainer found, running locally..."
        end
        # Run locally with split: Claude on left, shell on right
        # Step 1: cd to worktree
        tmux send-keys -t "$session_name:$window_name" "cd $worktree_path" Enter
        # Step 2: Split with Claude script on left, current pane becomes right with shell
        tmux split-window -t "$session_name:$window_name" -hb -p 50 -c "$worktree_path" "fish $launch_script"
    end

    # Create state file for post-completion hook (directory already created for launch script)
    set -l state_file "$worktree_path/.claude/ticket-execute.local.md"

    # Determine if ticket tracking should be skipped
    set -l auto_generated_str "false"
    if $is_auto_generated
        set auto_generated_str "true"
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
---

# Ticket Execution State

This file tracks the autonomous execution of ticket $issue_key.

When the ralph-loop completes (outputs the completion promise),
the post-completion hook will:
1. Create a PR
2. Transition the ticket (skipped if auto_generated)
3. Send notification

## Prompt Given

$prompt" > $state_file

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
