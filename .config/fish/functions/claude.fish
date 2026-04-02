function claude --description "Claude Code with interactive profile failover"
    if set -q CLAUDE_ROTATE_DISABLE
        command claude $argv
        return $status
    end

    set -l passthrough_flags \
        -p --print \
        --help -h \
        --version

    set -l passthrough_commands \
        update \
        config \
        mcp \
        doctor \
        install \
        uninstall \
        login \
        logout \
        auth \
        plugin \
        agents

    for arg in $argv
        if contains -- $arg $passthrough_flags
            command claude $argv
            return $status
        end
    end

    if test (count $argv) -gt 0
        set -l first_arg $argv[1]
        if contains -- $first_arg $passthrough_commands
            command claude $argv
            return $status
        end
    end

    set -l runner "$HOME/dotfiles/scripts/claude/run-with-rotation.sh"
    if not test -x "$runner"
        command claude $argv
        return $status
    end

    bash "$runner" $argv
end
