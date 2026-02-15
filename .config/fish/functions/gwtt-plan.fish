function gwtt-plan --description "Orchestrate multiple gwtt runs as a convoy"
    # Delegate: gwtt --plan <args> calls this function
    #
    # Usage:
    #   gwtt-plan <convoy-name> "Title:Description" [...] [options]
    #   gwtt-plan <convoy-name> --file tasks.md [options]
    #   gwtt-plan <convoy-name> --decompose "High-level goal description" [options]
    #   gwtt-plan resume <convoy-name> [options]
    #
    # All unrecognized flags are passed through to each gwtt invocation.

    # --- Handle resume subcommand ---
    if test (count $argv) -ge 2 -a "$argv[1]" = resume
        _gwtt_plan_resume $argv[2..]
        return $status
    end

    set -l convoy_name ""
    set -l task_file ""
    set -l decompose_desc ""
    set -l stagger 10
    set -l dry_run false
    set -l tasks
    set -l gwtt_passthrough
    set -l skip_next false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end

        set -l arg $argv[$i]
        set -l next_i (math $i + 1)

        switch $arg
            case --file -f
                if test $next_i -le (count $argv)
                    set task_file $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --file requires a path"
                    return 1
                end
            case --decompose -d
                if test $next_i -le (count $argv)
                    set decompose_desc $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --decompose requires a description"
                    return 1
                end
            case --stagger
                if test $next_i -le (count $argv)
                    set stagger $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --stagger requires seconds"
                    return 1
                end
            case --dry-run
                set dry_run true
            case --help -h
                echo "gwtt-plan - Orchestrate multiple gwtt runs as a convoy"
                echo ""
                echo "USAGE:"
                echo "  gwtt-plan <convoy-name> \"Title:Description\" [...] [options]"
                echo "  gwtt-plan <convoy-name> --file tasks.md [options]"
                echo "  gwtt-plan <convoy-name> --decompose \"Build auth system\" [options]"
                echo ""
                echo "TASK SOURCES (mutually exclusive):"
                echo "  Inline specs        \"Task Title:Task description text\""
                echo "  --file, -f FILE     Read tasks from markdown file (## headings)"
                echo "  --decompose, -d DESC  AI decomposes description into tasks"
                echo ""
                echo "FILE FORMAT (markdown):"
                echo "  ## Task Title"
                echo "  Description paragraph. Multiple lines joined."
                echo ""
                echo "OPTIONS:"
                echo "  --stagger N        Seconds between spawns (default: 10)"
                echo "  --dry-run          Show what would be spawned without executing"
                echo "  --help, -h         Show this help"
                echo ""
                echo "PASS-THROUGH OPTIONS (forwarded to each gwtt):"
                echo "  --template, --sub, --local, --model, --max, --bridge, etc."
                echo "  Any flag not listed above is forwarded to gwt-ticket."
                echo "  Note: --prompt-prefix is reserved for plan context injection."
                echo ""
                echo "EXAMPLES:"
                echo "  # Inline task specs"
                echo "  gwtt-plan auth-overhaul \\"
                echo "    \"Add OAuth:Google OAuth with PKCE flow\" \\"
                echo "    \"Add sessions:JWT with refresh tokens\" \\"
                echo "    \"Add RBAC:Role-based access control\""
                echo ""
                echo "  # From markdown file"
                echo "  gwtt-plan auth-overhaul --file auth-tasks.md --template implement"
                echo ""
                echo "  # AI decomposition"
                echo "  gwtt-plan auth-overhaul --decompose \"Build complete auth with OAuth, sessions, and RBAC\""
                echo ""
                echo "  # Via gwtt alias"
                echo "  gwtt --plan auth-overhaul --decompose \"Add payment processing\""
                echo ""
                echo "  # Resume failed/pending tasks from a previous plan"
                echo "  gwtt-plan resume auth-overhaul"
                return 0
            case '-*'
                # Pass-through: collect flag and its value if next arg isn't a flag
                set -a gwtt_passthrough $arg
                if test $next_i -le (count $argv)
                    set -l next_val $argv[$next_i]
                    if not string match -q -- '-*' $next_val
                        set -a gwtt_passthrough $next_val
                        set skip_next true
                    end
                end
            case '*'
                if test -z "$convoy_name"
                    set convoy_name $arg
                else
                    set -a tasks $arg
                end
        end
    end

    if test -z "$convoy_name"
        echo "Error: Convoy name required"
        echo "Usage: gwtt-plan <convoy-name> [task-specs...] [--file f] [--decompose desc]"
        return 1
    end

    # --- Task source: AI decomposition ---
    if test -n "$decompose_desc"
        if not command -q claude
            echo "Error: 'claude' CLI not found (required for --decompose)"
            return 1
        end

        echo "Decomposing plan with Claude..."
        echo "  Goal: $decompose_desc"
        echo ""

        set -l decompose_prompt "You are a technical project planner. Break this project goal into independent, parallelizable implementation tasks.

Requirements:
- Each task must be completable by a single developer in one coding session
- Tasks should be independent (no task depends on another completing first)
- Each task needs a clear, specific title and a detailed description
- Aim for 2-7 tasks (prefer fewer, well-scoped tasks over many small ones)

Output ONLY a JSON array. No markdown, no explanation, no code fences:
[{\"title\": \"Short task title\", \"description\": \"Detailed description of what to implement, including specific files, APIs, or components to create\"}]

Project goal: $decompose_desc"

        set -l json_output (claude -p --model sonnet "$decompose_prompt" 2>/dev/null)

        if test $status -ne 0; or test -z "$json_output"
            echo "Error: Claude decomposition failed"
            return 1
        end

        # Parse JSON output into task specs
        set -l parsed (printf '%s\n' $json_output | python3 -c "
import sys, json
text = sys.stdin.read()
# Find JSON array in output (Claude sometimes adds surrounding text)
start = text.find('[')
end = text.rfind(']') + 1
if start == -1 or end == 0:
    sys.exit(1)
tasks = json.loads(text[start:end])
for t in tasks:
    title = t['title'].replace(':', ' -')  # Escape colons in titles
    desc = t['description'].replace('\n', ' ')
    print(title + ':' + desc)
" 2>/dev/null)

        if test $status -ne 0
            echo "Error: Failed to parse decomposition output"
            echo "Raw output:"
            printf '%s\n' $json_output
            return 1
        end

        for line in $parsed
            set -a tasks $line
        end

        echo "Decomposed into "(count $parsed)" tasks:"
        for line in $parsed
            set -l t (string split -m1 ':' $line)[1]
            echo "  - $t"
        end
        echo ""
    end

    # --- Task source: Markdown file ---
    if test -n "$task_file"
        if not test -f "$task_file"
            echo "Error: File not found: $task_file"
            return 1
        end

        set -l parsed (awk '
            /^## / {
                if (title != "") {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc)
                    if (desc == "") desc = title
                    print title ":" desc
                }
                title = substr($0, 4)
                desc = ""
                next
            }
            title != "" && /^[^#]/ && !/^[[:space:]]*$/ {
                line = $0
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                if (line != "") {
                    if (desc != "") desc = desc " "
                    desc = desc line
                }
            }
            END {
                if (title != "") {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc)
                    if (desc == "") desc = title
                    print title ":" desc
                }
            }
        ' "$task_file")

        for line in $parsed
            set -a tasks $line
        end
    end

    # --- Validate we have tasks ---
    if test (count $tasks) -eq 0
        echo "Error: No tasks specified"
        echo "Provide inline specs, --file, or --decompose"
        return 1
    end

    set -l task_count (count $tasks)

    # --- Build task titles list for plan context ---
    set -l all_titles
    for i in (seq $task_count)
        set -l spec $tasks[$i]
        set -l t (string split -m1 ':' $spec)[1]
        set -a all_titles $t
    end

    # --- Build plan context prefix (injected into each agent's prompt) ---
    set -l task_list_text ""
    for i in (seq $task_count)
        if test -n "$task_list_text"
            set task_list_text "$task_list_text; $i. $all_titles[$i]"
        else
            set task_list_text "$i. $all_titles[$i]"
        end
    end

    # --- Strip --prompt-prefix from passthrough (we replace it with plan context) ---
    set -l filtered_passthrough
    set -l user_prefix ""
    set -l skip_filter false
    for j in (seq (count $gwtt_passthrough))
        if $skip_filter
            set skip_filter false
            continue
        end
        if test "$gwtt_passthrough[$j]" = --prompt-prefix
            set -l next_j (math $j + 1)
            if test $next_j -le (count $gwtt_passthrough)
                set user_prefix $gwtt_passthrough[$next_j]
                set skip_filter true
            end
        else
            set -a filtered_passthrough $gwtt_passthrough[$j]
        end
    end

    # --- Summary ---
    echo "Plan: $convoy_name"
    echo "Tasks: $task_count"
    if test (count $filtered_passthrough) -gt 0
        echo "Pass-through: $filtered_passthrough"
    end
    echo "Stagger: "$stagger"s between spawns"
    echo ""

    for i in (seq $task_count)
        echo "  [$i] $all_titles[$i]"
    end
    echo ""

    # --- Dry run ---
    if $dry_run
        echo "--- DRY RUN ---"
        echo ""
        for i in (seq $task_count)
            set -l spec $tasks[$i]
            set -l title (string split -m1 ':' $spec)[1]
            set -l desc (string split -m1 ':' $spec)[2]
            if test -z "$desc"
                set desc $title
            end
            set -l prefix "[Plan: $convoy_name | Task $i/$task_count: $title] "
            if test -n "$user_prefix"
                set prefix "$user_prefix $prefix"
            end
            echo "  gwt-ticket \"$title\" \"$desc\" --convoy $convoy_name --prompt-prefix \"$prefix...\" $filtered_passthrough"
        end
        echo ""
        echo "$task_count tasks would be spawned in convoy: $convoy_name"
        return 0
    end

    # --- Confirm before spawning ---
    read -l -P "Spawn $task_count tasks? [Y/n] " confirm
    if test "$confirm" = n -o "$confirm" = N
        echo "Cancelled."
        return 0
    end

    # --- Save plan manifest for resume ---
    set -l plan_dir "$HOME/.claude/plans"
    mkdir -p "$plan_dir"
    set -l manifest "$plan_dir/$convoy_name.json"
    printf '%s\n' $tasks | python3 -c "
import sys, json
tasks = [line.strip() for line in sys.stdin if line.strip()]
passthrough = '''$filtered_passthrough'''.split() if '''$filtered_passthrough''' else []
manifest = {
    'convoy_name': '$convoy_name',
    'tasks': tasks,
    'passthrough': passthrough,
    'stagger': $stagger,
    'user_prefix': '''$user_prefix'''
}
json.dump(manifest, open('$manifest', 'w'), indent=2)
" 2>/dev/null

    # --- Spawn each task with plan context ---
    set -l spawned 0
    set -l failed 0

    for i in (seq $task_count)
        set -l spec $tasks[$i]
        set -l title (string split -m1 ':' $spec)[1]
        set -l desc (string split -m1 ':' $spec)[2]
        if test -z "$desc"
            set desc $title
        end

        # Build plan-aware prompt prefix for this task
        set -l plan_prefix "PLAN CONTEXT: You are task $i of $task_count in plan '$convoy_name'. YOUR TASK: $title. ALL TASKS IN THIS PLAN: $task_list_text. Focus ONLY on your assigned task. Other tasks are handled by separate agents in parallel worktrees. Do not implement work belonging to other tasks."

        if test -n "$user_prefix"
            set plan_prefix "$user_prefix

$plan_prefix"
        end

        echo "[$i/$task_count] Spawning: $title"

        if gwt-ticket "$title" "$desc" --convoy $convoy_name --prompt-prefix "$plan_prefix" $filtered_passthrough
            set spawned (math $spawned + 1)
        else
            set failed (math $failed + 1)
            echo "  Warning: Failed to spawn task $i"
        end

        if test $i -lt $task_count
            echo "  Waiting "$stagger"s..."
            sleep $stagger
        end
    end

    echo ""
    echo "Convoy '$convoy_name': $spawned spawned, $failed failed"
    echo ""
    echo "Monitor:"
    echo "  gwt-convoy status (convoy-id)      # Convoy progress"
    echo "  gwt-status --convoy                # Convoy-grouped view"
    echo "  gwt-dashboard open                 # Web dashboard"
    echo "  gwtt-plan resume $convoy_name      # Re-run failed tasks"
end

function _gwtt_plan_resume --description "Resume failed/pending tasks from a previous plan"
    set -l convoy_name ""
    set -l stagger 10
    set -l dry_run false
    set -l extra_passthrough
    set -l skip_next false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end
        set -l arg $argv[$i]
        set -l next_i (math $i + 1)
        switch $arg
            case --stagger
                if test $next_i -le (count $argv)
                    set stagger $argv[$next_i]
                    set skip_next true
                end
            case --dry-run
                set dry_run true
            case --help -h
                echo "gwtt-plan resume - Re-run failed/pending tasks from a plan"
                echo ""
                echo "USAGE:"
                echo "  gwtt-plan resume <convoy-name> [--stagger N] [--dry-run]"
                echo ""
                echo "Reads the plan manifest and convoy status, then re-spawns"
                echo "only tasks with failed or pending status."
                return 0
            case '-*'
                set -a extra_passthrough $arg
                if test $next_i -le (count $argv)
                    set -l next_val $argv[$next_i]
                    if not string match -q -- '-*' $next_val
                        set -a extra_passthrough $next_val
                        set skip_next true
                    end
                end
            case '*'
                if test -z "$convoy_name"
                    set convoy_name $arg
                end
        end
    end

    if test -z "$convoy_name"
        echo "Error: Convoy name required"
        echo "Usage: gwtt-plan resume <convoy-name>"
        return 1
    end

    # Load plan manifest
    set -l manifest "$HOME/.claude/plans/$convoy_name.json"
    if not test -f "$manifest"
        echo "Error: No plan manifest found for '$convoy_name'"
        echo "  Expected: $manifest"
        echo "  Plans are saved automatically when gwtt-plan spawns tasks."
        return 1
    end

    # Find convoy script
    set -l convoy_script "$HOME/dotfiles/scripts/convoy.sh"
    if not test -x "$convoy_script"
        set convoy_script "$HOME/dotfiles-gastown/scripts/convoy.sh"
    end

    # Read manifest
    set -l manifest_data (cat "$manifest")
    set -l all_tasks (printf '%s' $manifest_data | python3 -c "
import sys, json
m = json.load(sys.stdin)
for t in m['tasks']:
    print(t)" 2>/dev/null)

    set -l saved_passthrough (printf '%s' $manifest_data | python3 -c "
import sys, json
m = json.load(sys.stdin)
print(' '.join(m.get('passthrough', [])))" 2>/dev/null)

    set -l user_prefix (printf '%s' $manifest_data | python3 -c "
import sys, json
m = json.load(sys.stdin)
print(m.get('user_prefix', ''))" 2>/dev/null)

    if test (count $all_tasks) -eq 0
        echo "Error: No tasks in manifest"
        return 1
    end

    set -l task_count (count $all_tasks)

    # Get convoy status to find failed/pending tasks
    set -l convoy_id ""
    if test -x "$convoy_script"
        set convoy_id (bash "$convoy_script" find-or-create "$convoy_name" 2>/dev/null | tail -1)
    end

    # Determine which tasks need re-running
    set -l tasks_to_run
    set -l task_indices

    if test -n "$convoy_id"
        set -l convoy_json (bash "$convoy_script" status "$convoy_id" --json 2>/dev/null)
        if test -n "$convoy_json"
            # Get titles that are still pending or failed
            for i in (seq $task_count)
                set -l spec $all_tasks[$i]
                set -l title (string split -m1 ':' $spec)[1]
                # Check if this title's ticket is completed in the convoy
                set -l task_status (printf '%s' "$convoy_json" | python3 -c "
import sys, json
c = json.load(sys.stdin)
title = '$title'
# Match by checking if any ticket key contains the title or is pending/failed
for tk, st in c.get('status', {}).items():
    if title.lower().replace(' ', '-') in tk.lower() or title.lower() in tk.lower():
        print(st)
        break
else:
    print('not-found')
" 2>/dev/null)
                if test "$task_status" != completed
                    set -a tasks_to_run $spec
                    set -a task_indices $i
                end
            end
        else
            # Can't read convoy status — re-run all
            for i in (seq $task_count)
                set -a tasks_to_run $all_tasks[$i]
                set -a task_indices $i
            end
        end
    else
        # No convoy found — re-run all
        for i in (seq $task_count)
            set -a tasks_to_run $all_tasks[$i]
            set -a task_indices $i
        end
    end

    if test (count $tasks_to_run) -eq 0
        echo "All tasks in plan '$convoy_name' are complete. Nothing to resume."
        return 0
    end

    # Build task titles for context
    set -l all_titles
    for i in (seq $task_count)
        set -l t (string split -m1 ':' $all_tasks[$i])[1]
        set -a all_titles $t
    end
    set -l task_list_text ""
    for i in (seq $task_count)
        if test -n "$task_list_text"
            set task_list_text "$task_list_text; $i. $all_titles[$i]"
        else
            set task_list_text "$i. $all_titles[$i]"
        end
    end

    echo "Resume: $convoy_name"
    echo "Re-running: "(count $tasks_to_run)" of $task_count tasks"
    echo ""
    for j in (seq (count $tasks_to_run))
        set -l idx $task_indices[$j]
        echo "  [$idx] $all_titles[$idx]"
    end
    echo ""

    if $dry_run
        echo "--- DRY RUN ---"
        echo "(count $tasks_to_run) tasks would be re-spawned"
        return 0
    end

    read -l -P "Spawn "(count $tasks_to_run)" tasks? [Y/n] " confirm
    if test "$confirm" = n -o "$confirm" = N
        echo "Cancelled."
        return 0
    end

    # Build passthrough args
    set -l final_passthrough
    if test -n "$saved_passthrough"
        set final_passthrough (string split ' ' $saved_passthrough)
    end
    for arg in $extra_passthrough
        set -a final_passthrough $arg
    end

    set -l spawned 0
    set -l failed_count 0

    for j in (seq (count $tasks_to_run))
        set -l spec $tasks_to_run[$j]
        set -l idx $task_indices[$j]
        set -l title (string split -m1 ':' $spec)[1]
        set -l desc (string split -m1 ':' $spec)[2]
        if test -z "$desc"
            set desc $title
        end

        set -l plan_prefix "PLAN CONTEXT: You are task $idx of $task_count in plan '$convoy_name' (RESUMED). YOUR TASK: $title. ALL TASKS IN THIS PLAN: $task_list_text. Focus ONLY on your assigned task. Other tasks are handled by separate agents in parallel worktrees. Do not implement work belonging to other tasks."

        if test -n "$user_prefix"
            set plan_prefix "$user_prefix

$plan_prefix"
        end

        echo "[$j/"(count $tasks_to_run)"] Resuming: $title"

        if gwt-ticket "$title" "$desc" --convoy $convoy_name --prompt-prefix "$plan_prefix" $final_passthrough
            set spawned (math $spawned + 1)
        else
            set failed_count (math $failed_count + 1)
            echo "  Warning: Failed to spawn task $idx"
        end

        if test $j -lt (count $tasks_to_run)
            echo "  Waiting "$stagger"s..."
            sleep $stagger
        end
    end

    echo ""
    echo "Resume '$convoy_name': $spawned spawned, $failed_count failed"
end
