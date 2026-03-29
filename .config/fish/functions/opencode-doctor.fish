function opencode-doctor --description "Run OpenCode project preflight checks"
    set -l script "$HOME/dotfiles/scripts/opencode/doctor.sh"

    if not test -x "$script"
        echo "Error: OpenCode doctor script not found: $script" >&2
        return 1
    end

    $script $argv
end
