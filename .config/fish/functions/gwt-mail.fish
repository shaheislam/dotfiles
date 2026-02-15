function gwt-mail --description "Lightweight persistent mail for agent worktrees"
    set -l mail_script "$HOME/dotfiles/scripts/agent-mail.sh"

    if not test -x "$mail_script"
        echo "Error: agent-mail.sh not found or not executable"
        echo "Expected: $mail_script"
        return 1
    end

    bash "$mail_script" $argv
end
