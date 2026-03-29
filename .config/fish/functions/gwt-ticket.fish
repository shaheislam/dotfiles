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
    #   --max-turns N   Max agentic turns per Claude session (budget cap)
    #   --max-budget N  Max API spend in USD before stopping (e.g., 5.00)
    #   --command C     Slash command to use (default: /ralph-loop:ralph-loop)
    #   --prompt-template F  File with custom prompt template
    #   --prompt-prefix P    Text to prepend to prompt
    #   --prompt-suffix S    Text to append to prompt
    #   --edit               Read description from per-repo gwtt-prompt.local.md (default)
    #   --no-edit            Use title as description instead of prompt file
    #   --desc-file FILE     Read description from file (- for stdin; avoids quote issues)
    #   --skill NAME [...]  Invoke skill(s) at prompt start
    #   --add-dir PATH [...] Additional directories for Claude --add-dir
    #   --local         Use local Ollama model (default: qwen3-coder)
    #   --model MODEL   Use specific Ollama model (implies --local)
    #   --mount, -m     Additional mount (repeatable)
    #   --session S     Tmux session name (default: repo name)
    #   --devcon        Use devcontainer for isolation (default: local)
    #   --sub NAME      Claude subscription profile (maps to ~/.claude-NAME config dir)
    #   --provider P    API provider profile (bedrock, vertex, foundry, gateway, or custom)
    #   --system S      Ticketing system: linear or jira
    #   --opencode-model M  OpenCode model override (implies --codex)
    #   --codex         Use OpenCode on the right-hand side instead of Claude Code on the left
    #   --codex-model M Codex/OpenAI model override for OpenCode (implies --codex)
    #   --codex-profile P  Legacy compatibility flag; OpenCode auth comes from its own config
    #   --bridge        Enable Claude's cross-provider review flow
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
    set -l slash_command "/ralph-loop:ralph-loop"
    set -l prompt_template ""
    set -l prompt_prefix ""
    set -l prompt_suffix ""
    set -l skills
    set -l skills_skip_to 0
    set -l extra_dirs
    set -l extra_dirs_skip_to 0
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
    set -l max_turns ""
    set -l max_budget ""
    set -l quiet_mode true
    set -l edit_mode true
    set -l edit_prompt_file (gwtt-prompt-file 2>/dev/null; or echo "$HOME/dotfiles/.claude/gwtt-prompt.local.md")
    set -l opencode_model ""
    set -l opencode_provider ""
    set -l provider_display ""
    set -l use_codex false
    set -l codex_model ""
    set -l codex_profile ""
    set -l crown_mode false
    set -l crown_count 3
    set -l crown_agents ""
    set -l crown_judge council
    set -l crown_subs ""
    set -l crown_timeout 7200
    set -l crown_signal "" # internal: signal file path for sub-gwt-ticket in crown mode
    set -l plan_first false
    set -l validate_command ""
    set -l browser_validate false
    set -l mcps_include ""
    set -l mcps_exclude false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end
        # Skip args consumed by --skill's or --add-dir's multi-arg parsing
        if test $i -le $skills_skip_to; or test $i -le $extra_dirs_skip_to
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
            case --max-turns
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set max_turns $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --max-turns requires a number"
                    return 1
                end
            case --max-budget
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set max_budget $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --max-budget requires a dollar amount (e.g., 5.00)"
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
            case --add-dir
                # Consume all following non-flag arguments as additional directory paths
                set -l found_dir false
                set -l j (math $i + 1)
                while test $j -le (count $argv)
                    if string match -q -- '--*' $argv[$j]
                        break
                    end
                    set -l dir_path $argv[$j]
                    # Resolve to absolute path
                    set dir_path (realpath -- "$dir_path" 2>/dev/null; or echo "$dir_path")
                    if not test -d "$dir_path"
                        echo "Error: --add-dir path does not exist: $dir_path" >&2
                        return 1
                    end
                    set -a extra_dirs $dir_path
                    set found_dir true
                    set extra_dirs_skip_to $j
                    set j (math $j + 1)
                end
                if not $found_dir
                    echo "Error: --add-dir requires at least one directory path"
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
            case --opencode-model
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set opencode_model $argv[$next_i]
                    set use_codex true
                    set skip_next true
                else
                    echo "Error: --opencode-model requires a model id (e.g., openai/gpt-5.1-codex)"
                    return 1
                end
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
            case --crown
                set crown_mode true
                # Optional: --crown N sets contestant count
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    if string match -qr '^[0-9]+$' -- $argv[$next_i]
                        set crown_count $argv[$next_i]
                        set skip_next true
                    end
                end
            case --crown-agents
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set crown_agents $argv[$next_i]
                    set crown_mode true
                    set skip_next true
                else
                    echo "Error: --crown-agents requires a comma-separated list (e.g., claude,claude,codex)"
                    return 1
                end
            case --crown-judge
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l jpreset $argv[$next_i]
                    if not contains -- $jpreset council review redteam
                        echo "Error: Unknown crown judge preset '$jpreset'"
                        echo "Valid presets: council, review, redteam"
                        return 1
                    end
                    set crown_judge $jpreset
                    set crown_mode true
                    set skip_next true
                else
                    echo "Error: --crown-judge requires a preset (council|review|redteam)"
                    return 1
                end
            case --crown-subs
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set crown_subs $argv[$next_i]
                    set crown_mode true
                    set skip_next true
                else
                    echo "Error: --crown-subs requires comma-separated profile names (e.g., personal,work,backup)"
                    return 1
                end
            case --crown-timeout
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set crown_timeout $argv[$next_i]
                    set crown_mode true
                    set skip_next true
                else
                    echo "Error: --crown-timeout requires seconds"
                    return 1
                end
            case --crown-signal
                # Internal: used by crown parent to tell sub-gwt-ticket where to signal
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set crown_signal $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --crown-signal requires a file path"
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
                    echo "Error: --ckpt-agent requires agent name (claude-code, gemini, opencode)"
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
            case --edit
                set edit_mode true
            case --no-edit
                set edit_mode false
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
            case --plan-first
                set plan_first true
            case --validate
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set validate_command $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --validate requires a command (e.g., 'npm test')"
                    return 1
                end
            case --browser-validate
                set browser_validate true
            case --mcps
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set mcps_include $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --mcps requires a comma-separated list"
                    return 1
                end
            case --no-mcps
                set mcps_exclude true
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
        echo "  --max-turns N        Max agentic turns per Claude session (budget cap)"
        echo "  --max-budget N       Max API spend in USD before stopping (e.g., 5.00)"
        echo "  --command C          Slash command (default: /ralph-loop:ralph-loop)"
        echo "  --prompt-template F  Custom prompt template file"
        echo "  --prompt-prefix P    Text to prepend to prompt"
        echo "  --prompt-suffix S    Text to append to prompt"
        echo "  --skill NAME [...]   Invoke skill(s) at start of prompt (e.g., --skill bestpractice tdd)"
        echo "  --add-dir PATH [...] Additional directories for Claude --add-dir (e.g., --add-dir ~/other-repo)"
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
        echo "  --opencode-model M   OpenCode model override (implies --codex; e.g., openai/gpt-5.1-codex)"
        echo "  --codex              Use OpenCode on the right-hand side instead of Claude Code on the left"
        echo "  --codex-model M      Codex/OpenAI model override for OpenCode (implies --codex; e.g., gpt-5.1-codex)"
        echo "  --codex-profile P    Legacy compatibility flag; OpenCode auth comes from its own config"
        echo "  --crown [N]          Tournament mode: N agents compete, LLM judge picks winner (default: 3)"
        echo "  --crown-agents LIST  Comma-separated agent types per contestant (e.g., claude,claude,codex)"
        echo "  --crown-judge PRESET Judge mode: council|review|redteam (default: council)"
        echo "  --crown-subs LIST    Rotate subscription profiles across contestants (e.g., personal,work,backup)"
        echo "  --crown-timeout N    Max wait for all contestants in seconds (default: 7200)"
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
        echo "  --ckpt-agent NAME    Checkpoint agent type (claude-code, gemini, opencode)"
        echo "  --mayor              Register ticket with mayor for global tracking"
        echo "  --no-mayor           Disable mayor registration"
        echo "  --gate TYPE          Create phase gate (ci-pipeline, pr-review, human-input, dependency, bd-bead)"
        echo "  --gate-dep PATH      Dependency worktree for --gate dependency"
        echo "  --swarm-epic ID      Create bd swarm molecule from epic bead ID (e.g., bd-abc12)"
        echo "  --priority N         Bead priority (0=critical, 1=high, 2=medium, 3=low, 4=backlog)"
        echo "  --edit               Read description from per-repo gwtt-prompt.local.md (default)"
        echo "  --no-edit            Use title as description (skip prompt file)"
        echo "  --desc-file FILE     Read description from file (or - for stdin; avoids shell quoting)"
        echo "  --no-beads           Disable automatic beads subtask tracking"
        echo "  --plan-first         Start in plan mode, create plan before executing code changes"
        echo "  --validate CMD       Inject validation command into prompt (e.g., 'npm test', 'make check')"
        echo "  --browser-validate   Add browser validation step for web/UI projects (uses Playwright MCP)"
        echo "  --mcps LIST          Only allow specified MCPs (comma-separated, e.g., playwright,context7)"
        echo "  --no-mcps            Disable all MCP usage (use bash/scripts instead, saves context tokens)"
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
        echo "  # Reads per-repo .claude/gwtt-prompt.local.md (falls back to global)"
        echo "  gwt-ticket \"my-feature\""
        echo "  gwt-ticket ENG-123 \"Fix auth\" --max 30"
        echo ""
        echo "  # Skip prompt file, use title as description"
        echo "  gwt-ticket \"my-feature\" --no-edit"
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
        echo "  # Add extra directories for Claude to access"
        echo "  gwt-ticket ENG-123 \"Fix\" \"Desc\" --add-dir ~/other-repo"
        echo "  gwt-ticket ENG-123 \"Fix\" \"Desc\" --add-dir ~/lib-a ~/lib-b"
        echo ""
        echo "  # Run OpenCode on the right with an OpenAI/Codex model"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --opencode-model openai/gpt-5.1-codex"
        echo ""
        echo "  # Run OpenCode instead of Claude Code"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --codex"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --codex-model gpt-5.1-codex"
        echo ""
        echo "  # Crown tournament mode (N agents compete, LLM judges)"
        echo "  gwt-ticket --crown TICKET-123 \"Fix auth\" \"Description\""
        echo "  gwt-ticket --crown 5 TICKET-123 \"Fix auth\" \"Description\""
        echo "  gwt-ticket --crown --crown-agents claude,claude,codex TICKET-123 \"Fix auth\" \"Desc\""
        echo "  gwt-ticket --crown --bridge TICKET-123 \"Fix auth\" \"Desc\"  # each contestant uses bridge"
        echo "  gwt-ticket --crown --crown-judge redteam TICKET-123 \"Fix auth\" \"Desc\""
        echo "  gwt-ticket --crown --crown-subs personal,work,backup TICKET-123 \"Fix auth\" \"Desc\""
        echo ""
        echo "  # Plan-first mode (analyze before executing)"
        echo "  gwt-ticket ENG-123 \"Add auth\" \"OAuth2 flow\" --plan-first"
        echo ""
        echo "  # Inject validation loop"
        echo "  gwt-ticket ENG-123 \"Fix tests\" \"Details\" --validate 'npm test'"
        echo "  gwt-ticket ENG-123 \"Fix build\" \"Details\" --validate 'make check'"
        echo ""
        echo "  # Browser validation for web projects"
        echo "  gwt-ticket ENG-123 \"Fix UI\" \"Details\" --browser-validate"
        echo ""
        echo "  # MCP scoping (reduce context token usage)"
        echo "  gwt-ticket ENG-123 \"Fix bug\" \"Details\" --no-mcps"
        echo "  gwt-ticket ENG-123 \"Fix UI\" \"Details\" --mcps playwright,context7"
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

    if $use_codex
        if test -n "$codex_profile"
            echo "Warning: --codex-profile is ignored in OpenCode mode; use 'opencode auth login' for the OpenAI account you want." >&2
        end
        if $use_devcon
            echo "Warning: --devcon is ignored in --codex OpenCode mode." >&2
            set use_devcon false
        end
        if $bridge_mode
            echo "Warning: --bridge is ignored in --codex OpenCode mode." >&2
            set bridge_mode false
        end
        if test -z "$opencode_model"
            if test -n "$codex_model"
                if string match -q '*/*' -- "$codex_model"
                    set opencode_model "$codex_model"
                else
                    set opencode_model "openai/$codex_model"
                end
            else
                set opencode_model "openai/gpt-5.1-codex"
            end
        end
        if not command -q opencode
            echo "Error: OpenCode not found. Install: brew install opencode"
            return 1
        end
        set opencode_provider (string split -m1 '/' -- $opencode_model)[1]
        set provider_display $opencode_provider
        switch $opencode_provider
            case openai
                set provider_display OpenAI
            case anthropic
                set provider_display Anthropic
            case ollama
                set provider_display Ollama
        end
        # Soft doctor preflight — warn but don't block launch
        set -l doctor_script "$HOME/dotfiles/scripts/opencode/doctor.sh"
        if test -x "$doctor_script"
            set -l doctor_out (bash "$doctor_script" 2>&1)
            set -l doctor_exit $status
            if test $doctor_exit -ne 0
                echo "Warning: OpenCode doctor found issues:" >&2
                for line in $doctor_out
                    if string match -q 'FAIL*' -- $line
                        echo "  $line" >&2
                    end
                end
                echo "  Run 'opencode-doctor' for details." >&2
            end
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
        if $edit_mode
            if not test -f "$edit_prompt_file"
                echo "Error: Prompt file not found: $edit_prompt_file"
                echo "Are you inside a git repository? gwtt-prompt-file auto-creates per-repo prompt files."
                return 1
            end
            set description (cat "$edit_prompt_file")
            if test -z "$description"
                echo "Error: Prompt file is empty: $edit_prompt_file"
                return 1
            end
        else
            set description "$title" # Use title as description if not provided
        end
    end

    # Crown tournament mode: spawn N sub-gwt-tickets and a crown-witness
    # Only activates for the parent invocation (no --crown-signal means parent)
    if $crown_mode; and test -z "$crown_signal"
        # Validate crown count
        if test "$crown_count" -lt 2
            echo "Error: --crown requires at least 2 contestants (got: $crown_count)"
            return 1
        end

        # Get repo root for crown-witness --repo
        set -l _crown_git_common (git rev-parse --git-common-dir)
        set -l _crown_repo_root (realpath "$_crown_git_common/..")

        # Create crown directory
        set -l _crown_slug (string lower -- $issue_key | string replace -ra '[^a-z0-9]+' '-')
        set -l crown_dir "/tmp/crown-$_crown_slug"
        mkdir -p "$crown_dir"

        # Parse crown-agents list (default: all claude)
        set -l agent_list
        if test -n "$crown_agents"
            set agent_list (string split ',' -- $crown_agents)
            # If fewer agents than crown_count, cycle through them
        else
            for _n in (seq 1 $crown_count)
                set -a agent_list claude
            end
        end

        # Parse crown-subs list for rotation
        set -l sub_list
        if test -n "$crown_subs"
            set sub_list (string split ',' -- $crown_subs)
        end

        echo "=== Crown Tournament ==="
        echo "Contestants: $crown_count"
        echo "Judge:       $crown_judge"
        echo "Crown dir:   $crown_dir"
        if test -n "$crown_agents"
            echo "Agents:      $crown_agents"
        end
        if test -n "$crown_subs"
            echo "Subs:        $crown_subs"
        end
        echo ""

        # Spawn N sub-gwt-tickets
        for _ci in (seq 1 $crown_count)
            # Determine agent type for this contestant (cycle through agent_list)
            set -l _agent_idx (math "($_ci - 1) % (count \$agent_list) + 1")
            set -l _agent_type $agent_list[$_agent_idx]

            # Determine sub profile for this contestant (cycle through sub_list)
            set -l _sub_flag
            if test (count $sub_list) -gt 0
                set -l _sub_idx (math "($_ci - 1) % (count \$sub_list) + 1")
                set _sub_flag --sub $sub_list[$_sub_idx]
            else if test -n "$sub_profile"
                set _sub_flag --sub "$sub_profile"
            end

            # Build sub-ticket args
            set -l _sub_args
            set -a _sub_args $issue_key "$title — Crown $_ci" "$description"
            set -a _sub_args --max $max_iterations
            set -a _sub_args --crown-signal "$crown_dir/done-$_ci"

            # Agent type flag
            if test "$_agent_type" = codex
                set -a _sub_args --codex
                if test -n "$codex_model"
                    set -a _sub_args --codex-model $codex_model
                end
            end

            # Pass through common flags
            if $bridge_mode
                set -a _sub_args --bridge
                if test -n "$bridge_iterations"
                    set -a _sub_args $bridge_iterations
                end
                if test -n "$bridge_review_mode"
                    set -a _sub_args --bridge-mode $bridge_review_mode
                end
            end
            if test -n "$_sub_flag"
                set -a _sub_args $_sub_flag
            end
            if test -n "$provider_profile"
                set -a _sub_args --provider $provider_profile
            end
            if test -n "$slash_command"; and test "$slash_command" != "/ralph-loop:ralph-loop"
                set -a _sub_args --command $slash_command
            end
            if test (count $skills) -gt 0
                set -a _sub_args --skill $skills
            end
            if test (count $extra_dirs) -gt 0
                set -a _sub_args --add-dir $extra_dirs
            end
            if $use_local
                set -a _sub_args --local
                if test -n "$local_model"
                    set -a _sub_args --model $local_model
                end
            end
            if test -n "$prompt_template"
                set -a _sub_args --prompt-template $prompt_template
            end
            if test -n "$prompt_prefix"
                set -a _sub_args --prompt-prefix $prompt_prefix
            end
            if test -n "$prompt_suffix"
                set -a _sub_args --prompt-suffix $prompt_suffix
            end
            if $no_checkpoints
                set -a _sub_args --no-checkpoints
            end
            if not $use_dynamic_beads
                set -a _sub_args --no-beads
            end
            if not $edit_mode
                set -a _sub_args --no-edit
            end
            set -a _sub_args --quiet

            echo "Spawning contestant $_ci/$crown_count ($_agent_type)..."
            gwt-ticket $_sub_args
            or echo "Warning: Contestant $_ci failed to spawn" >&2
        end

        # Launch crown-witness in background
        set -l _witness_script ""
        for _p in ~/dotfiles/scripts/crown-witness.sh ~/dotfiles-cmux/scripts/crown-witness.sh
            if test -x "$_p"
                set _witness_script $_p
                break
            end
        end
        if test -n "$_witness_script"
            echo ""
            echo "Starting crown witness..."
            bash "$_witness_script" "$crown_dir" \
                --count $crown_count \
                --judge $crown_judge \
                --base main \
                --repo "$_crown_repo_root" \
                --timeout $crown_timeout \
                --poll-interval 30
        else
            echo "Error: crown-witness.sh not found" >&2
            return 1
        end

        echo ""
        echo "=== Crown tournament started ==="
        echo "Monitor: tail -f $crown_dir/crown-witness.log"
        echo "Verdict: $crown_dir/verdict.json"
        return 0
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

    # Crown contestant: append suffix from signal file (e.g., done-1 → crown-1)
    if test -n "$crown_signal"
        set -l _crown_num (string replace -r '.*done-' '' -- (basename "$crown_signal"))
        set branch_name "$branch_name-crown-$_crown_num"
        # Strip " — Crown N" from title to avoid double-suffix on the slug
        set title (string replace -r ' — Crown [0-9]+$' '' -- "$title")
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
        if test (count $extra_dirs) -gt 0
            echo "Add-dirs:  "(string join ', ' -- $extra_dirs)
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
        if test -n "$crown_signal"
            echo "Crown:     contestant (signal: $crown_signal)"
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

    # Harness init: activate pre-commit hooks and validate environment in worktree
    set -l harness_init "$worktree_path/scripts/harness/init.sh"
    if test -x "$harness_init"
        bash "$harness_init" >/dev/null 2>&1; or true
    end

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
        tmux new-session -d -s $session_name -n $window_name -c "$worktree_path"
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
        tmux new-window -t "$session_name:" -n $window_name -c "$worktree_path"
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

    # Harness preflight: verify harness features before launch
    set -l harness_verify "$worktree_path/scripts/harness/verify-harness.sh"
    if test -x "$harness_verify"
        set -l harness_status (bash "$harness_verify" --summary 2>/dev/null)
        if not $quiet_mode; and test -n "$harness_status"
            echo "  Harness: $harness_status"
        end
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
3. Work each subtask:
   bd update BEAD_ID --status=in_progress → code → run tests if applicable → commit → bd close BEAD_ID
   Hooks enforce syntax and formatting on commit. Focus on testing and bead lifecycle.
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

    # Inject living plan instructions (always active — plan.md is initialized at launch)
    set -l living_plan_suffix "

LIVING PLAN — A plan file exists at .plan.md for this session.
This file persists across context compactions and session restarts.

UPDATE .plan.md at these points:
- After initial codebase investigation (fill in Approach section)
- After completing each major subtask (update Progress + Current State)
- After a subagent returns results (capture key findings in Current State)
- Before any natural stopping point (update Next Steps)
- When making important decisions (add to Key Decisions)
- When an approach fails or a dead end is found (add to Failed Approaches with WHY it failed)
- When a command produces valuable results or solves a problem (add to Useful Commands)
- When closing a bead (update Progress checklist to match bead status)

DEAD-END PREVENTION: Before trying a new approach, check the Failed Approaches section.
If an approach is listed there, do NOT retry it — find an alternative.
When recording a failed approach, always include WHY it failed so future sessions understand.

Only save commands that are genuinely useful — not routine ls/git status calls.
ALWAYS use Edit (not Write) when updating .plan.md to avoid clobbering external edits.
The plan is your persistent memory. Hooks will re-inject it after compaction."
    if test -n "$prompt_suffix"
        set prompt_suffix "$prompt_suffix$living_plan_suffix"
    else
        set prompt_suffix "$living_plan_suffix"
    end

    # Inject plan-first mode instruction
    if $plan_first
        set -l plan_suffix "

PLAN-FIRST MODE — Before writing ANY code, create a detailed implementation plan:
1. Analyze the codebase to understand architecture, patterns, and conventions
2. Identify all files that need modification and why
3. Consider edge cases, risks, and alternative approaches
4. Present the plan with specific changes per file
5. Only after the plan is complete, switch to execution and implement
Spend time building good context before executing. Fresh, focused context beats bloated context."
        if test -n "$prompt_suffix"
            set prompt_suffix "$prompt_suffix$plan_suffix"
        else
            set prompt_suffix "$plan_suffix"
        end
    end

    # Inject validation loop command
    if test -n "$validate_command"
        set -l validate_suffix "

VALIDATION LOOP — After EVERY meaningful code change, run this validation command:
  $validate_command
If validation fails, fix the issue before proceeding. Do NOT skip validation between changes.
This is your primary feedback loop for code quality."
        if test -n "$prompt_suffix"
            set prompt_suffix "$prompt_suffix$validate_suffix"
        else
            set prompt_suffix "$validate_suffix"
        end
    end

    # Inject browser validation instruction
    if $browser_validate
        set -l browser_suffix "

BROWSER VALIDATION — After implementing UI changes, use Playwright MCP to verify:
1. Navigate to the relevant page
2. Take a screenshot to verify visual correctness
3. Test key interactions (clicks, form submissions)
4. Check for console errors
Use browser validation as part of your verification loop for any user-facing changes."
        if test -n "$prompt_suffix"
            set prompt_suffix "$prompt_suffix$browser_suffix"
        else
            set prompt_suffix "$browser_suffix"
        end
    end

    # Inject MCP scoping instruction
    if $mcps_exclude
        set -l mcp_suffix "

MCP RESTRICTIONS — Do NOT use any MCP tools during this session. Use bash commands, scripts, and direct file operations instead. MCPs consume excessive context tokens."
        if test -n "$prompt_suffix"
            set prompt_suffix "$prompt_suffix$mcp_suffix"
        else
            set prompt_suffix "$mcp_suffix"
        end
    else if test -n "$mcps_include"
        set -l mcp_suffix "

MCP RESTRICTIONS — Only use these MCP tools: $mcps_include
Avoid all other MCPs to keep context lean and focused. Use bash commands or scripts instead."
        if test -n "$prompt_suffix"
            set prompt_suffix "$prompt_suffix$mcp_suffix"
        else
            set prompt_suffix "$mcp_suffix"
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
        # --- OpenCode harness ---
        # In --codex mode we launch OpenCode on the host and seed the TUI prompt.
        printf '%s' "$oneline_prompt" >$prompt_cmd_file
        set -l opencode_cmd opencode
        if test -n "$opencode_model"
            set opencode_cmd "$opencode_cmd --model $opencode_model"
        end
        set -a _ls "set -l auth_list (opencode auth list 2>/dev/null | string collect)"
        set -a _ls "if not string match -iq '*$provider_display*' -- \$auth_list"
        set -a _ls "    echo 'OpenCode is not authenticated for $provider_display. Starting login...'"
        set -a _ls "    opencode auth login --provider $opencode_provider"
        set -a _ls "    set auth_list (opencode auth list 2>/dev/null | string collect)"
        set -a _ls "    if not string match -iq '*$provider_display*' -- \$auth_list"
        set -a _ls "        echo 'OpenCode login for $provider_display did not complete.'"
        set -a _ls '        exec fish'
        set -a _ls '    end'
        set -a _ls end
        # Usage limit preflight — check before launching OpenCode
        set -a _ls "bash '$HOME/dotfiles/scripts/opencode/usage-check.sh' --quiet"
        set -a _ls 'set -l _usage_exit $status'
        set -a _ls 'if test $_usage_exit -eq 1'
        set -a _ls "    echo 'OpenAI usage limit reached on current account.'"
        set -a _ls '    if functions -q opencode-accounts'
        set -a _ls '        opencode-accounts check-and-rotate'
        set -a _ls '    else'
        set -a _ls "        echo 'Run: opencode auth login --provider openai (to switch accounts)'"
        set -a _ls "        opencode auth login --provider openai"
        set -a _ls '    end'
        set -a _ls end
        set -a _ls "set -l initial_prompt (cat '$prompt_cmd_file')"
        set -a _ls "$opencode_cmd --prompt \"\$initial_prompt\""
    else
        # --- Claude harness: interactive with send-keys prompt delivery ---
        # Write prompt command to file as single line (for send-keys delivery via rename script)
        # Newlines collapsed to spaces — Claude handles single-line instructions fine
        # Escape backslashes then double quotes so they don't break the outer "..." wrapping
        set -l escaped_prompt (string replace -a '\\' '\\\\' -- "$oneline_prompt")
        set escaped_prompt (string replace -a '"' '\\"' -- "$escaped_prompt")
        if string match -q '*/ralph-loop:ralph-loop*' $slash_command
            printf '%s' "$slash_command \"$escaped_prompt\" --max-iterations $max_iterations --completion-promise $completion_promise" >$prompt_cmd_file
        else
            printf '%s' "$slash_command \"$escaped_prompt\"" >$prompt_cmd_file
        end
        set -l claude_budget_flags ""
        if test -n "$max_turns"
            set claude_budget_flags "$claude_budget_flags --max-turns $max_turns"
        end
        if test -n "$max_budget"
            set claude_budget_flags "$claude_budget_flags --max-budget-usd $max_budget"
        end
        # Build extra --add-dir flags for additional directories
        set -l extra_dir_flags ""
        for edir in $extra_dirs
            set extra_dir_flags "$extra_dir_flags --add-dir $edir"
        end
        set -a _ls 'claude --dangerously-skip-permissions --effort max --remote-control --name '$window_name' --add-dir '$add_dir_path$extra_dir_flags$claude_budget_flags
    end

    if not $use_devcon
        # Pane stays open for witness to use (conflict resolution, debugging)
        set -l agent_name "Claude Code"
        $use_codex; and set agent_name OpenCode
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
            set _agent_label OpenCode
            set _cmd_label "Mode:      opencode --model $opencode_model"
        end
        set -l _primary_label "Claude Code"
        set -l _layout_label "Claude left | nvim top-right | terminal bottom-right"
        if $use_codex
            set _primary_label OpenCode
            set _layout_label "OpenCode left | nvim top-right | terminal bottom-right"
        end
        set -a _log "Agent:     $_agent_label" \
            "Primary:   $_primary_label" \
            "Layout:    $_layout_label" \
            "Title:     $title" \
            "Branch:    $branch_name" \
            "Worktree:  $worktree_path" \
            "Tmux:      $session_name:$window_name" \
            "Max iter:  $max_iterations" \
            "$_cmd_label"
        if test (count $skills) -gt 0
            set -a _log "Skills:    "(string join ', ' -- $skills)
        end
        if test (count $extra_dirs) -gt 0
            set -a _log "Add-dirs:  "(string join ', ' -- $extra_dirs)
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

    # Write prompt to markdown file for nvim visibility (record only, not a source)
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

    # Initialize living plan document before nvim launches so it's in the buffer list
    set -l plan_file "$worktree_path/.plan.md"
    if not test -f "$plan_file"
        echo "---
ticket: \"$issue_key\"
title: \"$title\"
created: \""(date -u +%Y-%m-%dT%H:%M:%SZ)"\"
last_updated: \""(date -u +%Y-%m-%dT%H:%M:%SZ)"\"
---

# Plan: $issue_key

## Objective

$title
$description

## Approach

_To be filled by the agent as work begins._

## Progress

- [ ] Investigation / codebase understanding
- [ ] Implementation
- [ ] Testing
- [ ] Verification

## Key Decisions

_Record important decisions and trade-offs here._

## Failed Approaches

_Record approaches that didn't work and WHY. This prevents retrying dead ends after compaction._

## Success Criteria

_Define quantifiable objectives. What does 'done' look like?_

## Known Limitations

_Track constraints and blockers discovered during work._

## Current State

_Update this section as work progresses. This survives context compaction._

## Next Steps

_What needs to happen next._

## Useful Commands

_Save commands here that produced valuable results or solved problems.
Include what the command does and why it matters. Format:_

\`\`\`bash
# Description of what this does and why it's useful
command --with-flags
\`\`\`
" >"$plan_file"
    end

    # plan.md is the living document — make it the active buffer when nvim opens
    # (prompt.local.md and other files become hidden buffers accessible via :ls)
    if test -f "$plan_file"
        set nvim_ai_files "$plan_file" $nvim_ai_files
    end

    # Common nvim launch flags: suppress messages + auto-reload timer for plan.md
    # Timer: 2s delay to let buffers load, then checktime every 5s for on-disk changes
    set -l nvim_base_cmd "nvim --cmd 'set shortmess=aoOtTIF' --cmd 'set cmdheight=10' --cmd 'lua vim.defer_fn(function() local t = vim.uv.new_timer() t:start(5000, 5000, vim.schedule_wrap(function() pcall(vim.cmd, \"checktime\") end)) end, 2000)'"
    set -l nvim_cmd "$nvim_base_cmd"
    if test (count $nvim_ai_files) -gt 0
        set nvim_cmd "$nvim_cmd $nvim_ai_files"
    end
    set -l nvim_launch_script "$instance_env/open-nvim.fish"
    printf '%s\n' \
        '#!/usr/bin/env fish' \
        "cd $worktree_path" \
        "$nvim_cmd" >$nvim_launch_script
    chmod +x $nvim_launch_script

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

        # Claude layout:
        # ┌──────────────┬──────────────┐
        # │ Claude Code  │ nvim CLAUDE.md│
        # │ (left)       │              │
        # │              ├──────────────┤
        # │              │   terminal   │
        # └──────────────┴──────────────┘
        set -l setup_script "$worktree_path/.claude/setup-panes.fish"
        set -l rename_script_devcon "$HOME/dotfiles/scripts/gwt-rename-session.sh"
        if not test -x "$rename_script_devcon"
            set rename_script_devcon "$HOME/dotfiles-rename/scripts/gwt-rename-session.sh"
        end
        printf '%s\n' \
            '#!/usr/bin/env fish' \
            '# Auto-generated by gwt-ticket - Claude left, editor+terminal right' \
            "$devcon_up_cmd" \
            'or begin' \
            "    echo 'Devcontainer failed to start'" \
            "    bash '$sandbox_script' default 2>/dev/null; or true" \
            '    exit 1' \
            end \
            'sleep 2' \
            "set -l right_pane_id (tmux display-message -p '#{pane_id}')" \
            "set -l claude_pane_id (tmux split-window -t \"\$right_pane_id\" -hb -p 35 -P -F '#{pane_id}' 'fish $claude_pane_script')" \
            "tmux split-window -t \"\$right_pane_id\" -v -p 30 -c '$worktree_path'" \
            "tmux send-keys -t \"\$right_pane_id\" 'fish $nvim_launch_script' Enter" \
            "bash '$rename_script_devcon' \"\$claude_pane_id\" '$window_name' '$prompt_cmd_file' &" \
            disown \
            'exec fish' >$setup_script
        chmod +x $setup_script

        # Short send-keys payload immune to direnv interference
        tmux send-keys -t "$session_name:$window_name" "fish $setup_script" Enter
    else
        if $use_codex
            # OpenCode layout:
            # ┌──────────────┬──────────────┐
            # │  OpenCode    │ nvim         │
            # │   (left)     ├──────────────┤
            # │              │ terminal     │
            # └──────────────┴──────────────┘
            set -l right_pane_id (tmux display-message -p -t "$session_name:$window_name" '#{pane_id}')
            set -l opencode_pane_id (tmux split-window -t "$right_pane_id" -hb -p 35 -P -F '#{pane_id}' "fish $launch_script")
            if test -z "$opencode_pane_id"
                echo "Error: Failed to create OpenCode pane in $session_name:$window_name" >&2
                builtin cd $_orig_pwd 2>/dev/null
                return 1
            end
            tmux split-window -t "$right_pane_id" -v -p 30 -c "$worktree_path"
            or echo "Warning: Failed to create terminal pane" >&2
            tmux send-keys -t "$right_pane_id" "fish $nvim_launch_script" Enter
            tmux rename-window -t "$session_name:$window_name" "$window_name" 2>/dev/null
        else
            # Claude layout:
            # ┌──────────────┬──────────────┐
            # │ Claude Code  │ nvim         │
            # │ (left)       ├──────────────┤
            # │              │ terminal     │
            # └──────────────┴──────────────┘
            set -l right_pane_id (tmux display-message -p -t "$session_name:$window_name" '#{pane_id}')
            set -l claude_pane_id (tmux split-window -t "$right_pane_id" -hb -p 35 -P -F '#{pane_id}' "fish $launch_script")
            if test -z "$claude_pane_id"
                echo "Error: Failed to create Claude pane in $session_name:$window_name" >&2
                builtin cd $_orig_pwd 2>/dev/null
                return 1
            end
            tmux split-window -t "$right_pane_id" -v -p 30 -c "$worktree_path"
            or echo "Warning: Failed to create terminal pane" >&2
            tmux send-keys -t "$right_pane_id" "fish $nvim_launch_script" Enter
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
plan_first: $plan_first
validate_command: \"$validate_command\"
browser_validate: $browser_validate
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

        # plan.md is now created synchronously before nvim launches (in nvim buffer list)

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
            # Crown mode: pass signal file paths to witness (skip merge, signal crown-witness)
            if test -n "$crown_signal"
                set witness_args $witness_args --crown-signal "$crown_signal"
                # Also write worktree path companion file for crown-witness
                set -l _crown_wt_signal (string replace '/done-' '/worktree-' -- "$crown_signal")
                set witness_args $witness_args --crown-worktree-signal "$_crown_wt_signal"
            end
            bash "$witness_script" $witness_args >/dev/null 2>&1 &
            disown 2>/dev/null
        end
    end </dev/null &
    disown 2>/dev/null

    # Restore caller's working directory (cd in begin...end & blocks can leak)
    builtin cd $_orig_pwd 2>/dev/null
end
