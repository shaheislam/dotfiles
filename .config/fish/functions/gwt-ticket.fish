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
    #   --desc-file FILE     Read description from file (- for stdin; avoids quote issues)
    #   --skill NAME [...]  Invoke skill(s) at prompt start
    #   --local         Use local Ollama model (default: qwen3-coder)
    #   --model MODEL   Use specific Ollama model (implies --local)
    #   --mount, -m     Additional mount (repeatable)
    #   --session S     Tmux session name (default: repo name)
    #   --devcon        Use devcontainer for isolation (default: local)
    #   --sub NAME      Claude subscription profile (maps to ~/.claude-NAME config dir)
    #   --provider P    API provider profile (bedrock, vertex, foundry, gateway, or custom)
    #   --system S      Ticketing system: linear or jira
    #   --codex         Use Codex CLI as primary agent instead of Claude Code
    #   --codex-model M Codex model override (implies --codex)
    #   --codex-profile P  Codex config profile from config.toml (implies --codex)
    #   --bridge        Enable iterative Codex→Claude review loop (requires --codex)
    #   --bridge-iterations N  Max bridge review cycles (default: 3)
    #   --bridge-mode M  Bridge review mode: review|redteam|steelman|assumptions
    #   --quiet, -q     Suppress verbose output (default, writes to .claude/gwt-ticket.log)
    #   --verbose, -v   Show full verbose output (overrides default quiet mode)
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
    set -l skills
    set -l skills_skip_to 0
    set -l sub_profile ""
    set -l provider_profile ""
    set -l bridge_mode false
    set -l workflow_template ""
    set -l show_status false
    set -l status_json false
    set -l gate_type ""
    set -l gate_dep_worktree ""
    set -l no_checkpoints false
    set -l ckpt_agent ""
    set -l bridge_iterations ""
    set -l use_local false
    set -l local_model ""
    set -l bridge_providers ""
    set -l bridge_verbose false
    set -l bridge_model ""
    set -l bridge_timeout ""
    set -l bridge_log ""
    set -l bridge_review_mode ""
    set -l bridge_models ""
    set -l bridge_dry_run false
    set -l bridge_cooldown ""
    set -l bridge_profiles ""
    set -l bridge_codex_profiles ""
    set -l auto_cleanup ""
    set -l rebase_merge false
    set -l convoy_id ""
    set -l molecule_id ""
    set -l town_sync true
    set -l mayor_tracked false
    set -l swarm_epic_id "" # bd swarm: epic bead ID to create swarm from
    set -l bead_priority "" # bd create --priority (0-4, empty = default)
    set -l use_dynamic_beads true
    set -l quiet_mode true
    set -l use_codex false
    set -l codex_model ""
    set -l codex_profile ""

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end
        # Skip args consumed by --skill's multi-arg parsing
        if test $i -le $skills_skip_to
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
            case --skill
                # Consume all following non-flag arguments as skill names
                set -l found_skill false
                set -l j (math $i + 1)
                while test $j -le (count $argv)
                    # Stop at next flag
                    if string match -q -- '--*' $argv[$j]
                        break
                    end
                    set -l skill_name $argv[$j]
                    # Normalize: strip leading / if present
                    set skill_name (string replace -r '^/' '' -- $skill_name)
                    set -a skills $skill_name
                    set found_skill true
                    set skills_skip_to $j
                    set j (math $j + 1)
                end
                if not $found_skill
                    echo "Error: --skill requires at least one skill name (e.g., --skill bestpractice tdd)"
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
            case --provider
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set provider_profile $argv[$next_i]
                    set -l conf_file "$HOME/.claude/providers/$provider_profile.conf"
                    if not test -f "$conf_file"
                        echo "Error: Provider '$provider_profile' not found ($conf_file)"
                        echo "Create one: cc-provider create $provider_profile"
                        return 1
                    end
                    set skip_next true
                else
                    echo "Error: --provider requires a name (bedrock, vertex, foundry, gateway)"
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
                    if string match -qr '^[0-9]+$' -- $argv[$next_i]
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
            case --bridge-mode
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l bmode $argv[$next_i]
                    if not contains -- $bmode review redteam steelman assumptions
                        echo "Error: Unknown bridge mode '$bmode'"
                        echo "Valid modes: review, redteam, steelman, assumptions"
                        return 1
                    end
                    set bridge_review_mode $bmode
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-mode requires a mode (review|redteam|steelman|assumptions)"
                    return 1
                end
            case --bridge-models
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set bridge_models $argv[$next_i]
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-models requires provider=model pairs (e.g., codex=o3,gemini=2.5-pro)"
                    return 1
                end
            case --bridge-dry-run
                set bridge_dry_run true
                set bridge_mode true
            case --bridge-cooldown
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set bridge_cooldown $argv[$next_i]
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-cooldown requires seconds (e.g., 300)"
                    return 1
                end
            case --bridge-profiles --bridge-claude-profiles
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set bridge_profiles $argv[$next_i]
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-profiles requires comma-separated profile names (e.g., work,personal)"
                    return 1
                end
            case --bridge-codex-profiles
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set bridge_codex_profiles $argv[$next_i]
                    set bridge_mode true
                    set skip_next true
                else
                    echo "Error: --bridge-codex-profiles requires comma-separated profile names (e.g., work,personal)"
                    return 1
                end
            case --codex
                set use_codex true
            case --codex-model
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set codex_model $argv[$next_i]
                    set use_codex true
                    set skip_next true
                else
                    echo "Error: --codex-model requires a model name (e.g., o3, gpt-5.4)"
                    return 1
                end
            case --codex-profile
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set codex_profile $argv[$next_i]
                    set use_codex true
                    set skip_next true
                else
                    echo "Error: --codex-profile requires a profile name from config.toml (e.g., auto, safe, fast, local)"
                    return 1
                end
            case --no-checkpoints
                set no_checkpoints true
            case --ckpt-agent
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set ckpt_agent $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --ckpt-agent requires agent name (claude-code, gemini, cursor, opencode)"
                    return 1
                end
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
            case --quiet -q
                set quiet_mode true
            case --verbose -v
                set quiet_mode false
            case --swarm-epic
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set swarm_epic_id $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --swarm-epic requires a bead epic ID (e.g., bd-abc12)"
                    return 1
                end
            case --priority
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l pval $argv[$next_i]
                    if not string match -qr '^[0-4]$' -- "$pval"
                        echo "Error: --priority must be 0-4 (got: $pval)"
                        return 1
                    end
                    set bead_priority $pval
                    set skip_next true
                else
                    echo "Error: --priority requires a value (0-4)"
                    return 1
                end
            case --no-beads
                set use_dynamic_beads false
            case --desc-file --description-file
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l desc_path $argv[$next_i]
                    if test "$desc_path" = -
                        set description (cat)
                    else if test -f "$desc_path"
                        set description (cat "$desc_path")
                    else
                        echo "Error: Description file not found: $desc_path"
                        return 1
                    end
                    set skip_next true
                else
                    echo "Error: --desc-file requires a file path (or - for stdin)"
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
        echo "  --skill NAME [...]   Invoke skill(s) at start of prompt (e.g., --skill bestpractice tdd)"
        echo "  --sub NAME           Claude subscription profile (uses ~/.claude-NAME config dir)"
        echo "  --provider NAME      API provider profile (bedrock, vertex, foundry, gateway, or custom)"
        echo "  --local              Use local Ollama model (default: qwen3-coder)"
        echo "  --model MODEL        Use specific Ollama model (implies --local)"
        echo "  --mount, -m          Add directory mount (repeatable)"
        echo "  --session S          Tmux session name (default: repo name)"
        echo "  --devcon             Use devcontainer for isolation (default: local)"
        echo "  --system S           Ticketing system: linear or jira"
        echo "  --bridge [N]         Enable cross-provider reasoning bridge (N=max iterations, default: 3)"
        echo "  --bridge-providers P Comma-separated provider order (codex,gemini,ollama,deepseek,claude,opencode)"
        echo "  --bridge-mode MODE   Review mode: review (default), redteam, steelman, assumptions"
        echo "  --bridge-verbose     Verbose bridge logging (level 1: prefix logs, use twice for level 2: banners)"
        echo "  --bridge-model M     Model override for first provider in --bridge-providers order"
        echo "  --bridge-models MAP  Per-provider model map (e.g., codex=o3,gemini=2.5-pro,ollama=qwen3-coder)"
        echo "  --bridge-timeout S   Per-provider timeout in seconds (default: 120)"
        echo "  --bridge-log FILE    Log bridge reviews to file"
        echo "  --bridge-dry-run     Show bridge config and provider availability without calling providers"
        echo "  --bridge-cooldown S  Cooldown seconds after rate limit (default: 300)"
        echo "  --bridge-profiles P  Claude subscription profiles for auto-rotation (e.g., work,personal)"
        echo "  --bridge-codex-profiles P  Codex profiles for auto-rotation (uses ~/.codex-<name>)"
        echo "  --codex              Use Codex CLI as primary agent (codex exec --full-auto)"
        echo "  --codex-model M     Codex model override (implies --codex; e.g., o3, gpt-5.4)"
        echo "  --codex-profile P   Codex config.toml profile (implies --codex; e.g., auto, safe, fast, local)"
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
        echo "  --ckpt-agent NAME    Checkpoint agent type (claude-code, gemini, cursor, opencode)"
        echo "  --mayor              Register ticket with mayor for global tracking"
        echo "  --no-mayor           Disable mayor registration"
        echo "  --gate TYPE          Create phase gate (ci-pipeline, pr-review, human-input, dependency, bd-bead)"
        echo "  --gate-dep PATH      Dependency worktree for --gate dependency"
        echo "  --swarm-epic ID      Create bd swarm molecule from epic bead ID (e.g., bd-abc12)"
        echo "  --priority N         Bead priority (0=critical, 1=high, 2=medium, 3=low, 4=backlog)"
        echo "  --desc-file FILE     Read description from file (or - for stdin; avoids shell quoting)"
        echo "  --no-beads           Disable automatic beads subtask tracking"
        echo "  --quiet, -q          Suppress verbose output (default; writes to .claude/gwt-ticket.log)"
        echo "  --verbose, -v        Show full verbose output (overrides default quiet mode)"
        echo "  --help, -h           Show this help"
        echo ""
        echo "Examples:"
        echo "  # Standard ticket execution"
        echo "  gwt-ticket ENG-123 \"Fix auth bug\" \"Session tokens expire incorrectly\""
        echo ""
        echo "  # Use a specific Claude subscription"
        echo "  gwt-ticket ENG-123 \"Fix auth bug\" \"Details\" --sub personal"
        echo ""
        echo "  # Use Bedrock instead of direct API"
        echo "  gwt-ticket ENG-123 \"Fix auth bug\" \"Details\" --provider bedrock"
        echo "  gwt-ticket ENG-123 \"Fix auth bug\" \"Details\" --provider vertex --sub work"
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
        echo "  # Description with quotes (from file or stdin)"
        echo "  gwt-ticket ENG-123 \"Fix bug\" --desc-file /tmp/description.txt"
        echo "  pbpaste | gwt-ticket ENG-123 \"Fix bug\" --desc-file -"
        echo ""
        echo "  # Add instructions before/after"
        echo "  gwt-ticket ENG-123 \"Fix\" \"Desc\" --prompt-prefix \"IMPORTANT: No test changes\""
        echo ""
        echo "  # Invoke skill(s) before working on the ticket"
        echo "  gwt-ticket ENG-123 \"Add feature\" \"Details\" --skill bestpractice"
        echo "  gwt-ticket ENG-123 \"Add feature\" \"Details\" --skill bestpractice tdd"
        echo ""
        echo "  # Run with Codex CLI instead of Claude Code"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --codex"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --codex-model o3"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --codex-profile auto"
        echo ""
        echo "  # Codex with Claude bridge review (Codex executes, Claude reviews)"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --codex --bridge"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --codex --bridge --bridge-mode redteam"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --codex --bridge 5 --bridge-profiles work"
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

    # Validate Codex CLI is available when --codex is specified
    if $use_codex
        if not command -q codex
            echo "Error: Codex CLI not found. Install: bun add -g @openai/codex"
            return 1
        end
    end

    # Show agent status
    if $show_status
        set -l agent_state_script ""
        for p in ~/dotfiles/scripts/agent-state.sh ~/dotfiles-gastown/scripts/agent-state.sh
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

    # Generate branch name (5 piped string ops instead of 8 — saves ~5ms)
    set -l slug (string lower -- $title | string replace -ra '[^a-z0-9]+' '-' | string replace -r '^-|-$' '' | string sub -l 30 | string replace -r -- '-$' '')
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

    # Log file path (set properly after worktree path resolution below)
    set -l gwt_log_file ""

    # --- Header block (verbose output) ---
    if not $quiet_mode
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
            if test -n "$bridge_review_mode"
                set bridge_info "$bridge_info, mode: $bridge_review_mode"
            end
            if test -n "$bridge_model"
                set bridge_info "$bridge_info, model: $bridge_model"
            end
            if test -n "$bridge_models"
                set bridge_info "$bridge_info, models: $bridge_models"
            end
            if test -n "$bridge_profiles"
                set bridge_info "$bridge_info, claude-profiles: $bridge_profiles"
            end
            if test -n "$bridge_codex_profiles"
                set bridge_info "$bridge_info, codex-profiles: $bridge_codex_profiles"
            end
            if test -n "$bridge_cooldown"
                set bridge_info "$bridge_info, cooldown: $bridge_cooldown""s"
            end
            set bridge_info "$bridge_info)"
            echo "Bridge:    $bridge_info"
            if $bridge_verbose
                echo "           verbose mode on"
            end
            if test -n "$bridge_log"
                echo "           log: $bridge_log"
            end
            if $bridge_dry_run
                echo "           dry-run mode (will show config only)"
            end
        end
        if test -n "$prompt_prefix"
            echo "Prefix:    (custom)"
        end
        if test -n "$prompt_suffix"
            echo "Suffix:    (custom)"
        end
        if test (count $skills) -gt 0
            echo "Skills:    "(string join ', ' -- $skills)
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
    end

    # Check inbox for pending instructions (skip in quiet mode — no output anyway)
    if not $quiet_mode
        set -l mail_script "$HOME/dotfiles/scripts/agent-mail.sh"
        if test -x "$mail_script"
            set -l unread_count (bash "$mail_script" count --for "$branch_name" 2>/dev/null)
            if test -n "$unread_count" -a "$unread_count" != 0
                echo "Mail: $unread_count unread message(s) for $branch_name"
                bash "$mail_script" inbox --for "$branch_name" --unread 2>/dev/null
                echo ""
            end
        end
    end

    # Preserve caller's working directory — background begin...end blocks
    # use cd $worktree_path and can leak to the parent shell in Fish.
    set -l _orig_pwd $PWD

    # Step 1: Create worktree via gwt-dev (reuses existing logic)
    if not $quiet_mode
        echo "[1/4] Creating worktree..."
    end
    set -l gwt_args $branch_name --no-devcon --no-cd
    if not test -d "$worktree_path"
        # Auto-generated tasks always need a new branch (skip show-ref check: saves ~20ms)
        # Real tickets may reuse an existing branch, so check first
        if $is_auto_generated
            set gwt_args $gwt_args --new
        else if not git show-ref --verify --quiet refs/heads/$branch_name
            set gwt_args $gwt_args --new
        end
        if $quiet_mode
            gwt-dev $gwt_args >/dev/null 2>&1
        else
            gwt-dev $gwt_args
        end
        if test $status -ne 0
            echo "Error: Failed to create worktree"
            return 1
        end
    else
        if not $quiet_mode
            echo "Worktree already exists, reusing..."
        end
    end

    # Resolve worktree path
    set worktree_path (realpath $worktree_path)

    # Now that worktree path is resolved, set up quiet mode log file
    if $quiet_mode
        set gwt_log_file "$worktree_path/.claude/gwt-ticket.log"
        mkdir -p "$worktree_path/.claude" 2>/dev/null
    end

    # Background metadata operations (bd + agent-cv) — tracking only, not needed
    # for Claude to start. Runs in subshell to avoid blocking tmux/Claude setup.
    # Saves ~4.5s (bd init 2.2s + bd create 1.5s + hook bead 0.75s).
    begin
        # Beads agent memory: init → work bead → hook bead → swarm
        if command -q bd
            if not test -d "$worktree_path/.beads"
                cd $worktree_path
                bd init --quiet >/dev/null 2>&1; or true
            end
            if test -d "$worktree_path/.beads"
                cd $worktree_path
                set -l bd_create_args "$title" --external-ref "$issue_key" --description "$description" --silent
                if test -n "$bead_priority"
                    set -a bd_create_args --priority $bead_priority
                end
                bd create $bd_create_args >/dev/null 2>&1; or true
                # GUPP Hook bead: ephemeral work-slung marker per Gastown Universal Propulsion Principle
                bd create "hook: $issue_key" \
                    --ephemeral \
                    --type event \
                    --event-category "agent.hooked" \
                    --event-target "$issue_key" \
                    --labels "gt:hook,gt:gupp" \
                    --silent >/dev/null 2>&1; or true
                # Agent bead: enables bd agent state/heartbeat tracking
                set -l agent_name "witness-"(basename $worktree_path)
                set -l agent_bead_id (bd q "$agent_name" --type task --labels "gt:agent" 2>/dev/null)
                if test -n "$agent_bead_id"
                    bd agent state "$agent_bead_id" spawning >/dev/null 2>&1; or true
                    bd kv set "agent.bead_id" "$agent_bead_id" >/dev/null 2>&1; or true
                end
                # Swarm molecule from epic (conditional)
                if test -n "$swarm_epic_id"
                    bd swarm create "$swarm_epic_id" >/dev/null 2>&1; or true
                end
            end
        end
        # Agent CV
        set -l cv_script "$HOME/dotfiles/scripts/agent-cv.sh"
        if test -x "$cv_script"
            set -l cv_args init "$worktree_path" --issue "$issue_key" --title "$title"
            if test -n "$sub_profile"
                set cv_args $cv_args --sub "$sub_profile"
            end
            if test -n "$local_model"
                set cv_args $cv_args --model "$local_model"
            end
            bash $cv_script $cv_args >/dev/null 2>&1; or true
        end
    end </dev/null &
    disown 2>/dev/null

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

    # Auto-enable checkpoints for worktree (via entire CLI) — backgrounded
    # Saves ~0.23s. Checkpoint hooks only needed when Claude makes its first commit
    # (seconds to minutes after launch), so safe to race with tmux setup.
    if not $no_checkpoints
        if command -q entire
            begin
                if test -f "$repo_root/.entire/settings.json"
                    mkdir -p "$worktree_path/.entire"
                    cp "$repo_root/.entire/settings.json" "$worktree_path/.entire/settings.json"
                end
                cd $worktree_path
                set -l entire_args enable
                if test -n "$ckpt_agent"
                    set -a entire_args --agent $ckpt_agent
                end
                entire $entire_args >/dev/null 2>&1; or true
            end </dev/null &
            disown 2>/dev/null
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
    if not $quiet_mode
        echo "[2/4] Setting up tmux session..."
    end
    set -l created_new_session false
    if not tmux has-session -t $session_name 2>/dev/null
        # Create session with the ticket window as the initial window
        # This avoids an extra default window (which would show reattach-to-user-namespace)
        tmux new-session -d -s $session_name -n $window_name
        or begin
            echo "Error: Failed to create tmux session '$session_name'" >&2
            builtin cd $_orig_pwd 2>/dev/null
            return 1
        end
        set created_new_session true
        if not $quiet_mode
            echo "Created tmux session: $session_name"
        end
    else
        if not $quiet_mode
            echo "Tmux session exists: $session_name"
        end
    end

    # Step 3: Create window for this ticket (only if session already existed)
    if not $quiet_mode
        echo "[3/4] Creating ticket window..."
    end

    if test "$created_new_session" = false
        # Session existed, create a new window for this ticket
        # Trailing colon forces session-level targeting — without it, tmux
        # resolves bare "dotfiles" as window main:dotfiles when a window
        # with that name exists in the current session.
        tmux new-window -t "$session_name:" -n $window_name
        or begin
            echo "Error: Failed to create tmux window '$window_name' in session '$session_name'" >&2
            builtin cd $_orig_pwd 2>/dev/null
            return 1
        end
    end
    if not $quiet_mode
        echo "Created window: $window_name"
    end

    # Step 4: Build and launch Claude
    if not $quiet_mode
        echo "[4/4] Launching Claude with $slash_command..."
    end

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
            builtin cd $_orig_pwd 2>/dev/null
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

    # Inject dynamic beads workflow instructions into prompt_suffix
    if $use_dynamic_beads; and command -q bd
        set -l beads_suffix "

BEADS SUBTASK TRACKING — A parent bead was created for this ticket (external-ref: $issue_key).

ALWAYS decompose multi-step tasks into subtasks. Only skip decomposition for true single-file, single-change fixes.

Workflow:
1. Find the parent bead: bd list --status=open
2. Create subtasks linked to parent:
   bd create --title='SUBTASK_TITLE' --description='WHY_AND_WHAT' --type=task --priority=2 --parent PARENT_BEAD_ID
   Use 'bd dep add CHILD_ID BLOCKER_ID' if ordering matters.
3. Work each subtask: bd update BEAD_ID --status=in_progress → code → bd close BEAD_ID
4. Between subtasks: bd ready (shows what is unblocked next)

Subtask state survives context compaction via bd prime.

REQUIRED BEHAVIORS:
- ALWAYS use 'bd comments add ID \"why I chose approach X over Y\"' for decisions and trade-offs
- ALWAYS use 'bd q \"discovered issue\"' to capture issues found during work (silent, returns only ID)
- ALWAYS use 'bd update ID --append-notes \"finding or decision\"' to record findings
- ALWAYS use 'bd search \"keyword\"' to check for related beads before creating new ones
- Close multiple: bd close ID1 ID2 ID3 (batch close is more efficient)
- Check blocked: bd blocked (see what needs unblocking)
- Store metadata: bd kv set key value (persistent across compactions)"

        if test -n "$prompt_suffix"
            set prompt_suffix "$prompt_suffix$beads_suffix"
        else
            set prompt_suffix "$beads_suffix"
        end
    end

    # Apply skills, prefix, and suffix
    set -l prompt ""

    # Inject skill invocations at the very start of the prompt
    if test (count $skills) -gt 0
        set -l skill_lines
        for skill in $skills
            set -a skill_lines "/$skill"
        end
        set prompt "IMPORTANT: Before starting the task below, invoke these skills in order:
"(string join \n -- $skill_lines)"

After the skills complete, proceed with the task:

"
    end

    if test -n "$prompt_prefix"
        set prompt "$prompt$prompt_prefix

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
    mkdir -p "$instance_env" "$HOME/.devcontainer/instances/$instance_name/work" "$worktree_path/.claude"

    # Write launch script to instance env dir (guaranteed mount inside container)
    set -l launch_script "$instance_env/launch-claude.fish"

    # repo_root is already resolved via realpath at line 676 — reuse directly
    # Compute paths: container-internal when using devcon, host paths otherwise
    set -l add_dir_path $repo_root
    set -l worktree_basename (basename $worktree_path)
    set -l repo_basename $repo
    if $use_devcon
        set add_dir_path "/mounts/$repo_basename"
    end

    # Build launch script content in a list, then write once (10x faster than individual echoes)
    # When using devcon, this script runs INSIDE the container via devcontainer exec
    set -l _ls # launch script lines
    set -a _ls '#!/usr/bin/env fish' ''

    # Set CLAUDE_CONFIG_DIR if subscription profile specified
    if test -n "$sub_profile"
        if $use_devcon
            set -a _ls "set -gx CLAUDE_CONFIG_DIR /home/node/.claude-$sub_profile"
        else
            set -a _ls "set -gx CLAUDE_CONFIG_DIR $HOME/.claude-$sub_profile"
        end
        set -a _ls ''
    end

    # Set provider env vars if --provider specified
    if test -n "$provider_profile"
        set -l conf_file "$HOME/.claude/providers/$provider_profile.conf"
        set -a _ls "# Provider: $provider_profile"
        while read -l line
            if string match -qr '^\s*#' "$line"; or string match -qr '^\s*$' "$line"
                continue
            end
            set -l kv (string replace -r '^\s*export\s+' '' "$line")
            set -l key (string split -m1 '=' "$kv")[1]
            set -l val (string split -m1 '=' "$kv")[2]
            set val (string trim -c "'" (string trim -c '"' "$val"))
            if test -n "$key" -a -n "$val"
                set -a _ls "set -gx $key $val"
            end
        end <"$conf_file"
        set -a _ls ''
    end

    # Set CROSS_PROVIDER_BRIDGE if bridge mode enabled
    if $bridge_mode
        set -a _ls "set -gx CROSS_PROVIDER_BRIDGE 1"
        if test -n "$bridge_iterations"
            set -a _ls "set -gx CROSS_PROVIDER_MAX_ITERATIONS $bridge_iterations"
        else
            set -a _ls "set -gx CROSS_PROVIDER_MAX_ITERATIONS 3"
        end
        test -n "$bridge_providers"; and set -a _ls "set -gx CROSS_PROVIDER_ORDER $bridge_providers"
        $bridge_verbose; and set -a _ls "set -gx CROSS_PROVIDER_VERBOSE 2"
        test -n "$bridge_review_mode"; and set -a _ls "set -gx CROSS_PROVIDER_MODE $bridge_review_mode"
        if test -n "$bridge_model"
            set -l first_provider (string split ',' -- (test -n "$bridge_providers"; and echo $bridge_providers; or echo "codex"))[1]
            switch $first_provider
                case codex
                    set -a _ls "set -gx CROSS_PROVIDER_CODEX_MODEL $bridge_model"
                case gemini
                    set -a _ls "set -gx CROSS_PROVIDER_GEMINI_MODEL $bridge_model"
                case ollama
                    set -a _ls "set -gx CROSS_PROVIDER_OLLAMA_MODEL $bridge_model"
                case deepseek
                    set -a _ls "set -gx CROSS_PROVIDER_DEEPSEEK_MODEL $bridge_model"
                case claude
                    set -a _ls "set -gx CROSS_PROVIDER_CLAUDE_MODEL $bridge_model"
                case opencode
                    set -a _ls "set -gx CROSS_PROVIDER_OPENCODE_MODEL $bridge_model"
            end
        end
        test -n "$bridge_models"; and set -a _ls "set -gx CROSS_PROVIDER_MODELS $bridge_models"
        test -n "$bridge_timeout"; and set -a _ls "set -gx CROSS_PROVIDER_TIMEOUT $bridge_timeout"
        test -n "$bridge_log"; and set -a _ls "set -gx CROSS_PROVIDER_LOG $bridge_log"
        $bridge_dry_run; and set -a _ls "set -gx CROSS_PROVIDER_DRY_RUN 1"
        test -n "$bridge_cooldown"; and set -a _ls "set -gx CROSS_PROVIDER_COOLDOWN $bridge_cooldown"
        test -n "$bridge_profiles"; and set -a _ls "set -gx CROSS_PROVIDER_CLAUDE_PROFILES $bridge_profiles"
        test -n "$bridge_codex_profiles"; and set -a _ls "set -gx CROSS_PROVIDER_CODEX_PROFILES $bridge_codex_profiles"
        set -a _ls ''
    end

    # If using local Ollama, add auto-start and env var bridge
    if $use_local
        set -a _ls \
            '# Ensure Ollama is running (auto-start)' \
            'if not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1' \
            '    echo "Starting Ollama..."' \
            '    if test -d "/Applications/Ollama.app"' \
            '        open -a Ollama' \
            '    else' \
            '        ollama serve &>/dev/null &' \
            '    end' \
            '    set -l attempts 0' \
            '    while not curl -sf http://localhost:11434/api/tags >/dev/null 2>&1' \
            '        sleep 1' \
            '        set attempts (math $attempts + 1)' \
            '        if test $attempts -ge 30' \
            '            echo "Error: Ollama failed to start after 30s"' \
            '            exit 1' \
            '        end' \
            '    end' \
            '    echo "Ollama is running"' \
            end \
            '' \
            '# Ensure model is available' \
            "if not ollama list 2>/dev/null | string match -q '*$local_model*'" \
            "    echo 'Pulling model $local_model...'" \
            "    ollama pull $local_model" \
            end \
            '' \
            '# Bridge Claude Code to local Ollama' \
            'set -gx ANTHROPIC_BASE_URL http://localhost:11434' \
            'set -gx ANTHROPIC_API_KEY ollama' \
            "set -gx ANTHROPIC_MODEL $local_model" \
            ''
    end

    set -l prompt_cmd_file "$instance_env/prompt-cmd.txt"
    set -l oneline_prompt (string replace -a \n ' ' -- "$prompt")

    # cd first so the agent runs in the worktree (launch script is non-interactive,
    # so config.fish's interactive block is skipped — no direnv, no starship)
    set -a _ls "cd $worktree_path"

    if $use_codex
        # --- Codex harness ---
        # Codex exec: --full-auto = workspace-write sandbox + on-failure approval
        # cd already sets the working dir; no --add-dir on exec
        if test (count $mounts) -gt 0; and not $use_devcon
            echo "Warning: Codex exec does not support --mount; mounts will be ignored" >&2
        end
        set -l codex_cmd "codex-rotate exec --full-auto"
        if test -n "$codex_model"
            set codex_cmd "$codex_cmd --model $codex_model"
        end
        if test -n "$codex_profile"
            set codex_cmd "$codex_cmd --profile $codex_profile"
        end
        # Write prompt to file — agents read from this file at execution time
        # (avoids shell injection from prompt content with quotes, backticks, $(), etc.)
        printf '%s' "$oneline_prompt" >$prompt_cmd_file

        if $bridge_mode
            # --- Codex + Bridge: iterative Codex→Claude review loop ---
            # Resolve bridge review script path
            set -l bridge_script ""
            for p in ~/dotfiles/scripts/codex-bridge-review.sh ~/dotfiles-codexcli/scripts/codex-bridge-review.sh
                if test -x "$p"
                    set bridge_script $p
                    break
                end
            end
            if test -z "$bridge_script"
                echo "Error: codex-bridge-review.sh not found" >&2
                builtin cd $_orig_pwd 2>/dev/null
                return 1
            end
            # Build bridge wrapper args
            set -l bridge_args --max-iterations
            if test -n "$bridge_iterations"
                set bridge_args "$bridge_args $bridge_iterations"
            else
                set bridge_args "$bridge_args 3"
            end
            if test -n "$bridge_review_mode"
                set bridge_args "$bridge_args --mode $bridge_review_mode"
            end
            if test -n "$bridge_model"
                # bridge_model overrides the Claude reviewer model
                set bridge_args "$bridge_args --claude-model $bridge_model"
            end
            if test -n "$bridge_profiles"
                # Use first Claude profile for review
                set -l first_profile (string split ',' -- $bridge_profiles)[1]
                set bridge_args "$bridge_args --claude-profile $first_profile"
            end
            if test -n "$bridge_timeout"
                set bridge_args "$bridge_args --timeout $bridge_timeout"
            end
            $bridge_verbose; and set bridge_args "$bridge_args --verbose"
            $bridge_dry_run; and set bridge_args "$bridge_args --dry-run"
            set bridge_args "$bridge_args --prompt-file '$prompt_cmd_file'"
            set -a _ls "bash '$bridge_script' $bridge_args -- $codex_cmd"
        else
            # --- Codex only: single-shot execution ---
            set -a _ls (printf '%s "(cat \'%s\')"' "$codex_cmd" "$prompt_cmd_file")
        end
    else
        # --- Claude harness: interactive with send-keys prompt delivery ---
        # Write prompt command to file as single line (for send-keys delivery via rename script)
        # Newlines collapsed to spaces — Claude handles single-line instructions fine
        # Escape backslashes then double quotes so they don't break the outer "..." wrapping
        set -l escaped_prompt (string replace -a '\\' '\\\\' -- "$oneline_prompt")
        set escaped_prompt (string replace -a '"' '\\"' -- "$escaped_prompt")
        if string match -q '*/ralph-wiggum:ralph-loop*' $slash_command
            printf '%s' "$slash_command \"$escaped_prompt\" --max-iterations $max_iterations --completion-promise $completion_promise" >$prompt_cmd_file
        else
            printf '%s' "$slash_command \"$escaped_prompt\"" >$prompt_cmd_file
        end
        set -a _ls 'claude --dangerously-skip-permissions --add-dir '$add_dir_path
    end

    if not $use_devcon
        # Pane stays open for witness to use (conflict resolution, debugging)
        set -l agent_name Claude
        $use_codex; and set agent_name Codex
        set -a _ls '' \
            'set -l agent_exit $status' \
            'if test $agent_exit -ne 0' \
            "    echo '$agent_name exited with code ' \$agent_exit" \
            end \
            'exec fish'
    end

    # Single write: all launch script content at once
    printf '%s\n' $_ls >$launch_script
    chmod +x $launch_script

    # Write secondary agent script (auto-launches the non-primary agent in interactive mode)
    # Both agents always launch — the --codex flag only controls which receives the task prompt
    set -l secondary_script "$instance_env/secondary-agent.fish"
    set -l _ss # secondary script lines
    set -a _ss '#!/usr/bin/env fish' ''
    set -a _ss "cd $worktree_path" ''
    if $use_codex
        # Codex is primary → secondary is Claude (interactive, no prompt)
        set -a _ss '# Claude Code - interactive mode (secondary agent)'
        if test -n "$sub_profile"
            set -a _ss "set -gx CLAUDE_CONFIG_DIR $HOME/.claude-$sub_profile"
        end
        set -a _ss 'claude --dangerously-skip-permissions'
    else
        # Claude is primary → secondary is Codex (interactive, no prompt)
        set -a _ss '# Codex CLI - interactive mode (secondary agent)'
        set -l codex_cmd_interactive "codex-rotate --full-auto"
        if test -n "$codex_model"
            set codex_cmd_interactive "$codex_cmd_interactive --model $codex_model"
        end
        if test -n "$codex_profile"
            set codex_cmd_interactive "$codex_cmd_interactive --profile $codex_profile"
        end
        set -a _ss "$codex_cmd_interactive"
    end
    # Exit handler + fallback shell (secondary always runs on host)
    set -l _secondary_agent Codex
    $use_codex; and set _secondary_agent Claude
    set -a _ss '' \
        'set -l agent_exit $status' \
        'if test $agent_exit -ne 0' \
        "    echo '$_secondary_agent exited with code ' \$agent_exit" \
        end \
        'exec fish'
    printf '%s\n' $_ss >$secondary_script
    chmod +x $secondary_script

    # Fixed-position aliases: Claude ALWAYS top-left, Codex ALWAYS bottom-left
    # The --codex flag only controls which agent receives the task prompt
    # NOTE: declare before if-block so variables persist in function scope
    set -l claude_agent_script
    set -l codex_agent_script
    if $use_codex
        set claude_agent_script $secondary_script # Claude interactive (top-left)
        set codex_agent_script $launch_script # Codex with prompt (bottom-left)
    else
        set claude_agent_script $launch_script # Claude with prompt (top-left)
        set codex_agent_script $secondary_script # Codex interactive (bottom-left)
    end

    # Write gwt-ticket log early so it can be opened in nvim alongside AI files
    # Single write instead of ~20 individual echo commands (saves ~30ms)
    if $quiet_mode
        set -l _log "=== gwt-ticket ==="
        set -a _log "Started: "(date '+%Y-%m-%d %H:%M:%S')
        if $is_auto_generated
            set -a _log "Task:      $issue_key (autonomous, no ticket tracking)"
        else
            set -a _log "Ticket:    $issue_key - $title"
        end
        set -l _agent_label "Claude Code"
        set -l _cmd_label "Command:   $slash_command"
        if $use_codex
            if $bridge_mode
                set _agent_label "Codex CLI + Claude Bridge"
            else
                set _agent_label "Codex CLI"
            end
            set _cmd_label "Mode:      codex exec --full-auto"
            test -n "$codex_model"; and set _cmd_label "$_cmd_label --model $codex_model"
            test -n "$codex_profile"; and set _cmd_label "$_cmd_label --profile $codex_profile"
            if $bridge_mode
                set _cmd_label "$_cmd_label (bridge: $bridge_review_mode"
                test -n "$bridge_iterations"; and set _cmd_label "$_cmd_label, iter=$bridge_iterations"
                set _cmd_label "$_cmd_label)"
            end
        end
        set -l _primary_label Claude
        $use_codex; and set _primary_label Codex
        set -a _log "Agent:     $_agent_label" \
            "Claude:    top-left pane" \
            "Codex:     bottom-left pane" \
            "Primary:   $_primary_label" \
            "Title:     $title" \
            "Branch:    $branch_name" \
            "Worktree:  $worktree_path" \
            "Tmux:      $session_name:$window_name" \
            "Max iter:  $max_iterations" \
            "$_cmd_label"
        if test (count $skills) -gt 0
            set -a _log "Skills:    "(string join ', ' -- $skills)
        end
        set -a _log '' \
            'Monitoring:' \
            "  tmux attach -t $session_name" \
            "  tmux select-window -t $session_name:$window_name" \
            "  worktree-witness.sh status $worktree_path" \
            '' \
            'Post-completion:' \
            "  ticket-execute --complete $worktree_path" \
            "State file: $worktree_path/.claude/ticket-execute.local.md"
        printf '%s\n' $_log >$gwt_log_file
    end

    # Write prompt to markdown file for nvim visibility (and as a record)
    set -l prompt_md_file "$worktree_path/.claude/prompt.local.md"
    printf '%s\n' \
        "# $issue_key — $title" \
        '' \
        '## Prompt' \
        '' \
        "$prompt" >$prompt_md_file

    # Detect AI guidance files to auto-open in nvim buffers
    # prompt.local.md shown first (active buffer), then reference files as hidden buffers
    # CLAUDE.md: AI rules/constraints. AGENTS.md: practical agent rules (editable per-worktree)
    # gwt-ticket.log: execution details (quiet mode, not committed)
    # settings.local.json: per-worktree hook configuration (only in .claude/)
    # Priority: worktree root > .claude/ subdirectory
    set -l nvim_ai_files "$prompt_md_file"
    for ai_file in CLAUDE.md AGENTS.md
        if test -f "$worktree_path/$ai_file"
            set -a nvim_ai_files "$worktree_path/$ai_file"
        else if test -f "$worktree_path/.claude/$ai_file"
            set -a nvim_ai_files "$worktree_path/.claude/$ai_file"
        end
    end

    # Include gwt-ticket log in nvim buffers for optional review
    if test -n "$gwt_log_file" -a -f "$gwt_log_file"
        set -a nvim_ai_files "$gwt_log_file"
    end

    # Also open settings.local.json if present (hook configuration visibility)
    if test -f "$worktree_path/.claude/settings.local.json"
        set -a nvim_ai_files "$worktree_path/.claude/settings.local.json"
    end

    if $use_devcon
        # Build devcon up command - rebuild ensures fresh container with correct mounts
        # Without -r, devcontainer up reuses existing containers that may lack --mount binds
        set -l devcon_up_cmd "devcon claude -i $instance_name -r -E FORCE_AUTOUPDATE_PLUGINS=1 -E CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1"
        # Pass CLAUDE_CONFIG_DIR env var into container for subscription profile
        if test -n "$sub_profile"
            set devcon_up_cmd "$devcon_up_cmd -E CLAUDE_CONFIG_DIR=/home/node/.claude-$sub_profile"
        end
        # Pass provider env vars into container
        if test -n "$provider_profile"
            set -l conf_file "$HOME/.claude/providers/$provider_profile.conf"
            while read -l line
                if string match -qr '^\s*#' "$line"; or string match -qr '^\s*$' "$line"
                    continue
                end
                set -l kv (string replace -r '^\s*export\s+' '' "$line")
                set -l key (string split -m1 '=' "$kv")[1]
                set -l val (string split -m1 '=' "$kv")[2]
                set val (string trim -c "'" (string trim -c '"' "$val"))
                if test -n "$key" -a -n "$val"
                    set devcon_up_cmd "$devcon_up_cmd -E $key=$val"
                end
            end <"$conf_file"
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
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_VERBOSE=2"
            end
            if test -n "$bridge_review_mode"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_MODE=$bridge_review_mode"
            end
            if test -n "$bridge_models"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_MODELS=$bridge_models"
            end
            if test -n "$bridge_timeout"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_TIMEOUT=$bridge_timeout"
            end
            if test -n "$bridge_log"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_LOG=$bridge_log"
            end
            if $bridge_dry_run
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_DRY_RUN=1"
            end
            if test -n "$bridge_cooldown"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_COOLDOWN=$bridge_cooldown"
            end
            if test -n "$bridge_profiles"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_CLAUDE_PROFILES=$bridge_profiles"
            end
            if test -n "$bridge_codex_profiles"
                set devcon_up_cmd "$devcon_up_cmd -E CROSS_PROVIDER_CODEX_PROFILES=$bridge_codex_profiles"
            end
        end
        set devcon_up_cmd "$devcon_up_cmd $worktree_path $repo_root"
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
        printf '%s\n' \
            '#!/usr/bin/env fish' \
            "cd $worktree_path" \
            "$exec_cmd fish $container_launch_script" \
            'set -l claude_exit $status' \
            '' \
            'if test $claude_exit -ne 0' \
            "    echo 'Claude Code devcontainer exec failed (exit '\$claude_exit')'" \
            "    echo 'Container: $instance_name'" \
            "    echo 'Exec cmd: $exec_cmd'" \
            "    echo 'Script: $container_launch_script'" \
            '    exec fish' \
            end \
            '' \
            '# Pane stays open for witness to use (conflict resolution, debugging)' \
            'exec fish' >$claude_pane_script
        chmod +x $claude_pane_script

        # Fixed dual-agent layout (positions never change):
        # ┌──────────────┬──────────────┐
        # │ Claude Code  │ nvim CLAUDE.md│
        # │ (top-left)   │              │
        # ├──────────────┤              │
        # │ Codex CLI    ├──────────────┤
        # │ (bottom-left)│   terminal   │
        # └──────────────┴──────────────┘
        set -l setup_script "$worktree_path/.claude/setup-panes.fish"
        # Claude pane: devcontainer when primary, host when secondary (interactive)
        set -l devcon_claude_pane
        if $use_codex
            set devcon_claude_pane $claude_agent_script
        else
            set devcon_claude_pane $claude_pane_script
        end
        # Prompt delivery: only when Claude is primary (send-keys to Claude pane)
        set -l rename_line ""
        if $use_codex
            set rename_line "tmux rename-window '$window_name' 2>/dev/null"
        else
            set -l rename_script_devcon "$HOME/dotfiles/scripts/gwt-rename-session.sh"
            if not test -x "$rename_script_devcon"
                set rename_script_devcon "$HOME/dotfiles-rename/scripts/gwt-rename-session.sh"
            end
            set rename_line "bash '$rename_script_devcon' \"\$claude_pane_id\" '$window_name' '$prompt_cmd_file' &"
        end
        set -l nvim_cmd "nvim --cmd 'set shortmess=aoOtTIF' --cmd 'set cmdheight=10'"
        if test (count $nvim_ai_files) -gt 0
            set nvim_cmd "$nvim_cmd $nvim_ai_files"
        end
        printf '%s\n' \
            '#!/usr/bin/env fish' \
            "# Auto-generated by gwt-ticket - fixed dual-agent layout (Claude top-left, Codex bottom-left)" \
            "$devcon_up_cmd" \
            'or begin' \
            "    echo 'Devcontainer failed to start'" \
            "    bash '$sandbox_script' default 2>/dev/null; or true" \
            '    exit 1' \
            end \
            'sleep 2' \
            "# Step 1: Claude pane (top-left, always Claude)" \
            "set -l claude_pane_id (tmux split-window -hb -p 35 -P -F '#{pane_id}' 'fish $devcon_claude_pane')" \
            "# Step 2: Codex pane (bottom-left, always Codex)" \
            "tmux split-window -t \"\$claude_pane_id\" -v -p 40 'fish $codex_agent_script'" \
            "# Step 3: Right-side layout" \
            'tmux select-pane -R' \
            'tmux split-window -v -p 30' \
            "tmux send-keys 'cd $worktree_path' Enter" \
            'tmux select-pane -U' \
            "$rename_line" \
            disown \
            "$nvim_cmd" \
            'exec fish' >$setup_script
        chmod +x $setup_script

        # Short send-keys payload immune to direnv interference
        tmux send-keys -t "$session_name:$window_name" "fish $setup_script" Enter
    else
        # Fixed dual-agent layout (positions never change):
        # ┌──────────────┬──────────────┐
        # │ Claude Code  │ nvim CLAUDE.md│ ← top-right (70%)
        # │ (top-left)   │              │
        # ├──────────────┤              │
        # │ Codex CLI    ├──────────────┤
        # │ (bottom-left)│   terminal   │ ← bottom-right (30%)
        # └──────────────┴──────────────┘

        # Step 1: Claude pane (top-left, 35%) — always Claude
        set -l claude_pane_id (tmux split-window -t "$session_name:$window_name" -hb -p 35 -P -F '#{pane_id}' "fish $claude_agent_script")
        if test -z "$claude_pane_id"
            echo "Error: Failed to create Claude pane in $session_name:$window_name" >&2
            builtin cd $_orig_pwd 2>/dev/null
            return 1
        end

        # Step 2: Codex pane (bottom-left, 40% of left column) — always Codex
        set -l codex_pane_id (tmux split-window -t "$claude_pane_id" -v -p 40 -P -F '#{pane_id}' "fish $codex_agent_script")
        or echo "Warning: Failed to create Codex pane" >&2

        # Step 3: Switch to right pane and split for nvim + terminal
        tmux select-pane -t "$session_name:$window_name" -R
        tmux split-window -t "$session_name:$window_name" -v -p 30
        or echo "Warning: Failed to create terminal pane" >&2
        tmux send-keys -t "$session_name:$window_name" "cd $worktree_path" Enter

        # Step 4: Launch nvim in top-right pane
        tmux select-pane -t "$session_name:$window_name" -U
        if test (count $nvim_ai_files) -gt 0
            tmux send-keys -t "$session_name:$window_name" "cd $worktree_path && nvim --cmd 'set shortmess=aoOtTIF' --cmd 'set cmdheight=10' $nvim_ai_files" Enter
        else
            tmux send-keys -t "$session_name:$window_name" "cd $worktree_path && nvim --cmd 'set shortmess=aoOtTIF' --cmd 'set cmdheight=10'" Enter
        end

        # Step 5: Prompt delivery — to Claude pane (top-left) when Claude is primary
        if $use_codex
            # Codex is primary — prompt embedded in codex_agent_script CLI
            tmux rename-window -t "$session_name:$window_name" "$window_name" 2>/dev/null
        else
            # Claude is primary — deliver prompt via send-keys to Claude pane (top-left)
            set -l rename_script "$HOME/dotfiles/scripts/gwt-rename-session.sh"
            if not test -x "$rename_script"
                set rename_script "$HOME/dotfiles-rename/scripts/gwt-rename-session.sh"
            end
            bash "$rename_script" "$claude_pane_id" "$window_name" "$prompt_cmd_file" &
            disown
        end
    end

    # State file path (used in output and background block)
    set -l state_file "$worktree_path/.claude/ticket-execute.local.md"

    # Print output immediately so user sees feedback before background ops
    if $quiet_mode
        # Log was already written before pane setup (for nvim buffer visibility)
        echo "gwtt: $window_name → $session_name:$window_name (log: $gwt_log_file)"
    else
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

    # Post-launch orchestration — backgrounded since Claude is already active.
    # State file, gates, mayor, convoy, merge-queue, and witness are metadata
    # operations that don't affect Claude's execution. Saves ~1-2s.
    begin
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

        # Write state file for post-completion hook
        set -l auto_generated_str false
        if $is_auto_generated
            set auto_generated_str true
        end

        set -l agent_harness claude
        if $use_codex
            if $bridge_mode
                set agent_harness codex-bridge
            else
                set agent_harness codex
            end
        end

        echo "---
active: true
issue_key: \"$issue_key\"
title: \"$title\"
ticketing_system: \"$ticketing_system\"
agent_harness: \"$agent_harness\"
auto_generated: $auto_generated_str
started_at: \""(date -u +%Y-%m-%dT%H:%M:%SZ)"\"
max_iterations: $max_iterations
completion_promise: \"TICKET_"$issue_key"_COMPLETE\"
worktree_path: \"$worktree_path\"
tmux_session: \"$session_name\"
tmux_window: \"$window_name\"
claude_pane_id: \"$claude_pane_id\"
use_local: $use_local
local_model: \"$local_model\"
convoy_id: \"$convoy_id\"
molecule_id: \"$molecule_id\"
town_sync: $town_sync
mayor_tracked: $mayor_tracked
bead_priority: \"$bead_priority\"
dynamic_beads: $use_dynamic_beads
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
            for p in ~/dotfiles/scripts/phase-gates.sh ~/dotfiles-gastown/scripts/phase-gates.sh
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
                env $gate_env bash "$gates_script" create "$gate_type" "$worktree_path" 2>/dev/null; or true
            end
        end

        # Register with mayor for global tracking if --mayor specified
        if $mayor_tracked
            set -l mayor_script "$HOME/dotfiles/scripts/gwt-mayor.sh"
            if not test -x "$mayor_script"
                set mayor_script "$HOME/dotfiles-gastown/scripts/gwt-mayor.sh"
            end
            if test -x "$mayor_script"
                bash "$mayor_script" log-event ticket-registered "$issue_key" "$worktree_path" 2>/dev/null; or true
            end
        end

        # Add ticket to convoy
        if test -n "$convoy_id"
            set -l convoy_script "$HOME/dotfiles/scripts/convoy.sh"
            if not test -x "$convoy_script"
                set convoy_script "$HOME/dotfiles-gastown/scripts/convoy.sh"
            end
            if test -x "$convoy_script"
                bash "$convoy_script" add "$convoy_id" "$issue_key" 2>/dev/null; or true
            end
        end

        # Ensure merge-queue daemon is running
        set -l merge_queue_script ""
        for p in ~/dotfiles/scripts/merge-queue.sh ~/dotfiles-gastown/scripts/merge-queue.sh
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
                bash "$merge_queue_script" $daemon_args >/dev/null 2>&1
            end
        end

        # Spawn worktree witness (per-worktree lifecycle monitor)
        set -l witness_script "$HOME/dotfiles/scripts/worktree-witness.sh"
        if not test -x "$witness_script"
            set witness_script "$HOME/dotfiles-gastown/scripts/worktree-witness.sh"
        end
        if test -x "$witness_script"
            set -l witness_args "$worktree_path" --poll-interval 30 --max-retries 3
            if test -n "$auto_cleanup"
                set witness_args $witness_args $auto_cleanup
            end
            bash "$witness_script" $witness_args >/dev/null 2>&1 &
            disown 2>/dev/null
        end
    end </dev/null &
    disown 2>/dev/null

    # Restore caller's working directory (cd in begin...end & blocks can leak)
    builtin cd $_orig_pwd 2>/dev/null
end
