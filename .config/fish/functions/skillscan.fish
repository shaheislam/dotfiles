function skillscan --description "Scan AI agent skill bundles for security issues via SkillSpector"
    set -l subcommand $argv[1]
    set -l extra_args $argv[2..-1]

    if not command -q skillspector
        echo "Error: skillspector not installed. Run: pipx install skillspector" >&2
        return 1
    end

    # Scope LLM provider routing to this function only — setting OPENAI_BASE_URL
    # globally would redirect every OpenAI-compatible tool (codex, opencode,
    # claude pipeline) to Ollama, which is not what we want.
    set -lx SKILLSPECTOR_PROVIDER openai
    set -lx OPENAI_BASE_URL http://localhost:11434/v1
    set -lx OPENAI_API_KEY ollama
    set -e LANGCHAIN_TRACING_V2
    set -e LANGCHAIN_API_KEY

    set -l ts (date +%Y%m%d-%H%M%S)
    set -l out_dir "$HOME/.local/share/skillscan/$ts"
    mkdir -p $out_dir

    set -l target
    switch $subcommand
        case here ''
            set target (pwd)
        case skills
            set target "$HOME/dotfiles/skills"
        case claude-skills
            set target "$HOME/.claude/skills"
        case plugins
            set target "$HOME/.claude/plugins"
        case mcp
            set target "$HOME/.claude/mcp"
        case path
            set target $extra_args[1]
            set extra_args $extra_args[2..-1]
        case '*'
            echo "Usage: skillscan <here|skills|claude-skills|plugins|mcp|path <dir>> [extra skillspector args]"
            return 2
    end

    if not test -d $target; and not test -f $target
        echo "Error: target not found: $target" >&2
        return 1
    end

    echo "Scanning: $target"
    echo "Reports:  $out_dir"
    echo

    skillspector scan $target \
        --format sarif --output "$out_dir/report.sarif" \
        $extra_args
    set -l exit_code $status

    skillspector scan $target \
        --format markdown --output "$out_dir/report.md" \
        $extra_args >/dev/null 2>&1

    skillspector scan $target $extra_args
    return $exit_code
end
