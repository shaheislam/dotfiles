function checkpoints --description "Manage agent checkpoint system (ckpt)"
    # Wrapper for scripts/checkpoints.sh
    # Checkpoints link Claude Code session context to git commits,
    # storing reasoning on a checkpoints/v1 orphan branch.
    #
    # Usage:
    #   checkpoints enable [--strategy manual|auto]
    #   checkpoints disable [--purge]
    #   checkpoints status / checkpoints log / checkpoints show <sha>
    #   checkpoints resume [branch]    (context for resuming work)
    #   checkpoints context [--commits N]  (condensed session primer)
    #   checkpoints search <query>     (search checkpoint content)
    #   checkpoints rewind             (interactive fzf browser)
    #   checkpoints clean              (remove orphaned data)
    #   checkpoints reset [--force]    (delete checkpoint branch)
    #   checkpoints doctor

    # Find the script
    set -l scripts_dir ""
    for p in ~/dotfiles/scripts ~/dotfiles-entry/scripts
        if test -f "$p/checkpoints.sh"
            set scripts_dir $p
            break
        end
    end

    if test -z "$scripts_dir"
        echo "Error: checkpoints.sh not found in ~/dotfiles/scripts or ~/dotfiles-entry/scripts"
        return 1
    end

    bash "$scripts_dir/checkpoints.sh" $argv
end
