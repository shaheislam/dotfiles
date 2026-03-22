function claude-pipeline --description "Chain Claude Code models: reasoning → implementation pipeline"
    # Usage: claude-pipeline [options] <prompt>
    #
    # Pipes reasoning output from one Claude model as input to another.
    # Uses your Claude Code subscription (Max/Pro/Teams) - no API key needed.
    #
    # Default: opus (reasoning) → sonnet (implementation)

    if test "$argv[1]" = --help; or test "$argv[1]" = -h
        echo "Usage: claude-pipeline [options] <prompt>"
        echo ""
        echo "Chain Claude models: pass reasoning output as input to implementation."
        echo "Uses your Claude Code CLI subscription (no API key needed)."
        echo ""
        echo "Options:"
        echo "  --reason MODEL    Model for reasoning stage (default: opus)"
        echo "  --execute MODEL   Model for execution stage (default: sonnet)"
        echo "  --stages N        Number of stages (2-5, default: 2)"
        echo "  --stream          Use stream-json format between stages (structured)"
        echo "  --save FILE       Save intermediate outputs to files"
        echo "  --json            Output structured JSON from final stage"
        echo "  --json-schema F   JSON schema file for validated structured output"
        echo "  --dry-run         Show the pipeline command without executing"
        echo "  --system PROMPT   System prompt for all stages"
        echo "  --verbose         Show stage progress"
        echo ""
        echo "Pipeline Presets:"
        echo "  --preset think    opus → sonnet (default: deep reasoning → implementation)"
        echo "  --preset review   opus → sonnet → haiku (reason → implement → review)"
        echo "  --preset cheap    sonnet → haiku (balanced reasoning → fast execution)"
        echo "  --preset local    ollama → sonnet (local reasoning → cloud implementation)"
        echo "  --preset council  opus → sonnet → opus (3-round structured debate)"
        echo "  --preset redteam  opus → sonnet (adversarial attack → synthesis)"
        echo ""
        echo "Built-in Model Aliases:"
        echo "  opus      Opus 4.6 (deep reasoning, architecture)"
        echo "  sonnet    Sonnet 4.5 (balanced coding)"
        echo "  haiku     Haiku 4.5 (fast, simple tasks)"
        echo "  opusplan  Auto-switches opus→sonnet by mode (built-in)"
        echo ""
        echo "Examples:"
        echo "  claude-pipeline 'Design and implement a retry mechanism for API calls'"
        echo "  claude-pipeline --preset review 'Add input validation to user signup'"
        echo "  claude-pipeline --reason opus --execute haiku 'Write a bash one-liner to find large files'"
        echo "  echo 'existing code' | claude-pipeline 'refactor this with better error handling'"
        echo "  claude-pipeline --stages 3 'Build a REST API endpoint for user profiles'"
        echo "  claude-pipeline --save /tmp/pipeline 'Design a caching strategy'"
        echo "  claude-pipeline --dry-run 'Test pipeline command'"
        echo ""
        echo "How it works:"
        echo "  Stage 1 (reasoning): claude -p --model opus 'Analyze and plan: <prompt>'"
        echo "  Stage 2 (execution): claude -p --model sonnet 'Implement based on: <stage1 output>'"
        echo ""
        echo "Tip: Use 'opusplan' as your /model setting for in-session hybrid mode."
        echo "     This function is for explicit multi-stage pipelines in the terminal."
        echo ""
        echo "Related:"
        echo "  /model opusplan   Built-in hybrid mode (inside Claude Code TUI)"
        echo "  claude -p          Single-shot pipe mode"
        echo "  llm-code            Local Ollama coding queries"
        return 0
    end

    # Parse arguments
    set -l reason_model opus
    set -l execute_model sonnet
    set -l stages 2
    set -l use_stream false
    set -l save_prefix ""
    set -l dry_run false
    set -l system_prompt ""
    set -l verbose false
    set -l json_output false
    set -l json_schema ""
    set -l prompt_args
    set -l stage_models
    set -l stage_prompts

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --reason
                set i (math $i + 1)
                set reason_model $argv[$i]
            case --execute
                set i (math $i + 1)
                set execute_model $argv[$i]
            case --stages
                set i (math $i + 1)
                set stages $argv[$i]
            case --stream
                set use_stream true
            case --save
                set i (math $i + 1)
                set save_prefix $argv[$i]
            case --dry-run
                set dry_run true
            case --system
                set i (math $i + 1)
                set system_prompt $argv[$i]
            case --verbose
                set verbose true
            case --json
                set json_output true
            case --json-schema
                set i (math $i + 1)
                set json_schema $argv[$i]
                set json_output true
            case --preset
                set i (math $i + 1)
                switch $argv[$i]
                    case think
                        set reason_model opus
                        set execute_model sonnet
                        set stages 2
                    case review
                        set reason_model opus
                        set execute_model sonnet
                        set stages 3
                        set stage_models opus sonnet haiku
                        set stage_prompts "Analyze and create a detailed implementation plan for:" "Implement the plan from the previous analysis:" "Review the implementation for bugs, edge cases, and improvements:"
                    case cheap
                        set reason_model sonnet
                        set execute_model haiku
                        set stages 2
                    case local
                        set reason_model ollama
                        set execute_model sonnet
                        set stages 2
                    case council
                        set reason_model opus
                        set execute_model sonnet
                        set stages 3
                        set stage_models opus sonnet opus
                        set stage_prompts "Round 1 - State your position from multiple expert perspectives (architect, security, operations, user experience). Identify concerns, trade-offs, and risks for:" "Round 2 - Counter-argue the concerns raised. Steelman the proposal where valid, concede where criticisms hold. Respond to:" "Round 3 - Synthesize the debate. List: strongest arguments for, strongest arguments against, convergence points, unresolved tensions, and recommended changes for:"
                    case redteam
                        set reason_model opus
                        set execute_model sonnet
                        set stages 2
                        set stage_models opus sonnet
                        set stage_prompts "You are a hostile adversarial reviewer. BREAK this plan. Find: 1) Fatal flaws causing project failure 2) Hidden wrong assumptions 3) Missing failure modes 4) Optimistic estimates that will slip 5) Dependencies that will break. Be specific and ruthless. Attack:" "Synthesize the adversarial review into actionable findings. For each attack: rate severity (critical/high/medium/low), assess if the plan can survive it, and recommend specific mitigations. Review:"
                    case '*'
                        echo "Error: Unknown preset '$argv[$i]'"
                        echo "Available: think, review, cheap, local, council, redteam"
                        return 1
                end
            case '--*'
                echo "Error: Unknown option '$argv[$i]'"
                echo "Run: claude-pipeline --help"
                return 1
            case '*'
                set -a prompt_args $argv[$i]
        end
        set i (math $i + 1)
    end

    # Build prompt from remaining args or stdin
    set -l prompt ""
    if test (count $prompt_args) -gt 0
        set prompt (string join " " $prompt_args)
    end

    # Check for piped input
    set -l piped_input ""
    if not isatty stdin
        set piped_input (cat)
    end

    if test -z "$prompt" -a -z "$piped_input"
        echo "Error: No prompt provided"
        echo "Usage: claude-pipeline <prompt>"
        echo "  or:  echo 'context' | claude-pipeline 'instruction'"
        return 1
    end

    # If prompt is empty but we have piped input, use it as the prompt
    if test -z "$prompt"
        set prompt "$piped_input"
        set piped_input ""
    end

    # Prepend piped context if both exist
    if test -n "$piped_input"
        set prompt "Context:\n$piped_input\n\nTask: $prompt"
    end

    # Validate stages
    if test $stages -lt 2 -o $stages -gt 5
        echo "Error: Stages must be between 2 and 5"
        return 1
    end

    # Build stage models array if not set by preset
    if test (count $stage_models) -eq 0
        set stage_models $reason_model
        for s in (seq 2 $stages)
            set -a stage_models $execute_model
        end
    end

    # Build stage prompts if not set by preset
    if test (count $stage_prompts) -eq 0
        set stage_prompts "Analyze, reason deeply, and create a detailed plan for:"
        if test $stages -eq 2
            set -a stage_prompts "Based on the analysis above, implement the solution:"
        else
            for s in (seq 2 (math $stages - 1))
                set -a stage_prompts "Continue building on the previous stage's output. Stage $s of $stages:"
            end
            set -a stage_prompts "Finalize and implement based on all previous analysis:"
        end
    end

    # Build system prompt flag
    set -l system_flag
    if test -n "$system_prompt"
        set system_flag --system-prompt "$system_prompt"
    end

    # Build format flags
    set -l out_format_flag
    set -l in_format_flag
    if $use_stream
        set out_format_flag --output-format stream-json
        set in_format_flag --input-format stream-json
    end

    # Dry run - show the command
    if $dry_run
        echo "Pipeline: $stages stages"
        echo ""
        for s in (seq 1 $stages)
            set -l model $stage_models[$s]
            set -l sprompt $stage_prompts[$s]
            echo "Stage $s [$model]:"
            if test $s -eq 1
                echo "  claude -p --model $model $system_flag $out_format_flag '$sprompt $prompt'"
            else if test $s -eq $stages
                echo "  | claude -p --model $model $system_flag $in_format_flag '<stage "(math $s - 1)" output + $sprompt'"
            else
                echo "  | claude -p --model $model $system_flag $in_format_flag $out_format_flag '<stage "(math $s - 1)" output + $sprompt'"
            end
        end
        return 0
    end

    # Execute the pipeline
    if $verbose
        echo "claude-pipeline: $stages stages"
        for s in (seq 1 $stages)
            echo "  Stage $s: $stage_models[$s]"
        end
        echo ""
    end

    # Stage 1: Reasoning
    set -l stage1_model $stage_models[1]
    set -l stage1_prompt "$stage_prompts[1] $prompt"

    if $verbose
        echo "--- Stage 1/$stages [$stage1_model] ---"
    end

    # Handle local ollama model
    set -l stage1_cmd
    if test "$stage1_model" = ollama
        # Use local Ollama via claude-local in print mode
        set -l ollama_model (set -q LLM_CODE_MODEL; and echo $LLM_CODE_MODEL; or echo "qwen3-coder")
        set stage1_cmd "ANTHROPIC_BASE_URL=http://localhost:11434 ANTHROPIC_API_KEY=ollama ANTHROPIC_MODEL=$ollama_model claude -p $system_flag $out_format_flag '$stage1_prompt'"
    else
        set stage1_cmd "claude -p --model $stage1_model $system_flag $out_format_flag"
    end

    set -l output
    if test "$stage1_model" = ollama
        set -l ollama_model (set -q LLM_CODE_MODEL; and echo $LLM_CODE_MODEL; or echo "qwen3-coder")
        set output (ANTHROPIC_BASE_URL=http://localhost:11434 ANTHROPIC_API_KEY=ollama ANTHROPIC_MODEL=$ollama_model claude -p $system_flag "$stage1_prompt" 2>/dev/null)
    else
        set output (claude -p --model $stage1_model $system_flag "$stage1_prompt" 2>/dev/null)
    end

    if test $status -ne 0
        echo "Error: Stage 1 failed (model: $stage1_model)"
        return 1
    end

    # Save stage 1 output if requested
    if test -n "$save_prefix"
        echo "$output" >"$save_prefix-stage1.txt"
        if $verbose
            echo "  Saved: $save_prefix-stage1.txt"
        end
    end

    # Subsequent stages
    for s in (seq 2 $stages)
        set -l model $stage_models[$s]
        set -l sprompt $stage_prompts[$s]
        set -l stage_input "Previous stage output:\n$output\n\n$sprompt"

        if $verbose
            echo "--- Stage $s/$stages [$model] ---"
        end

        # Apply JSON output flags only to the final stage
        set -l final_stage_flags
        if test $s -eq $stages
            if $json_output
                set -a final_stage_flags --output-format json
            end
            if test -n "$json_schema"
                set -a final_stage_flags --json-schema $json_schema
            end
        end

        if test "$model" = ollama
            set -l ollama_model (set -q LLM_CODE_MODEL; and echo $LLM_CODE_MODEL; or echo "qwen3-coder")
            set output (ANTHROPIC_BASE_URL=http://localhost:11434 ANTHROPIC_API_KEY=ollama ANTHROPIC_MODEL=$ollama_model claude -p $system_flag $final_stage_flags "$stage_input" 2>/dev/null)
        else
            set output (claude -p --model $model $system_flag $final_stage_flags "$stage_input" 2>/dev/null)
        end

        if test $status -ne 0
            echo "Error: Stage $s failed (model: $model)"
            return 1
        end

        # Save intermediate output
        if test -n "$save_prefix"
            echo "$output" >"$save_prefix-stage$s.txt"
            if $verbose
                echo "  Saved: $save_prefix-stage$s.txt"
            end
        end
    end

    # Output final result
    echo "$output"
end
