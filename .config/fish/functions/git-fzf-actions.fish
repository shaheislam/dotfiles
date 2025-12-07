# Git FZF Action-Based Workflows
# Inspired by https://thevaluable.dev/fzf-git-integration/ and forgit
# Provides interactive git operations directly from fzf interface

# Helper function to get git status files
function __git_fzf_get_files
    set -l mode $argv[1]
    if test "$mode" = "add"
        # Show untracked and modified files (not staged)
        git status --short | grep -E '^\?\?|^.[MD]' | awk '{print $2}'
    else if test "$mode" = "reset"
        # Show staged files
        git diff --cached --name-only
    else
        # All modified files
        git status --short | awk '{print $2}'
    end
end

# Git Files Interface - Add/Reset Mode with Actions
function _git_fzf_file_actions
    # Check if in git repo
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end

    set -l selected (
        git status --short | \
        fzf --ansi \
            --multi \
            --border-label="📁 Git Files" \
            --header="ALT-P (patch) | ALT-D (discard) | ALT-C (commit) | ALT-A (amend) | ALT-E (edit) | CTRL-/ (preview)" \
            --preview="echo {} | awk '{print \$2}' | xargs git diff --color=always -- 2>/dev/null || echo {} | awk '{print \$2}' | xargs bat --color=always" \
            --preview-window="right:70%:wrap,<120(right,50%,wrap)" \
            --bind="alt-p:execute(echo {} | awk '{print \$2}' | xargs git add --patch < /dev/tty > /dev/tty)+reload(git status --short)" \
            --bind="alt-d:execute(echo {} | awk '{print \$2}' | xargs git checkout -- < /dev/tty > /dev/tty)+reload(git status --short)" \
            --bind="alt-c:execute(git commit < /dev/tty > /dev/tty)+reload(git status --short)" \
            --bind="alt-a:execute(git commit --amend < /dev/tty > /dev/tty)+reload(git status --short)" \
            --bind="alt-e:execute(echo {} | awk '{print \$2}' | xargs \$EDITOR < /dev/tty > /dev/tty)" \
            --bind="ctrl-/:toggle-preview"
    )

    if test -n "$selected"
        # Extract filenames and add them
        for line in $selected
            set -l file (echo $line | awk '{print $2}')
            git add $file
            echo "✅ Added: $file"
        end
    end
end

# Git Commits Interface - Operations on Commits (multi-select enabled)
function _git_fzf_commit_actions
    # Check if in git repo
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end

    set -l selected (
        git log --oneline --graph --date=short --color=always \
            --pretty='format:%C(auto)%cd %h%d %s (%an)' | \
        fzf --ansi \
            --multi \
            --bind 'tab:toggle+down,shift-tab:toggle+up' \
            --border-label="🍡 Git Commits" \
            --header="ENTER (show) | ALT-E (nvim) | ALT-C (checkout) | ALT-R (reset) | ALT-I (rebase) | ALT-P (pick) | ALT-F/S/W (fixup/squash/reword) | ALT-V (revert) | CTRL-/ (preview)" \
            --preview="echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git show --color=always" \
            --preview-window="right:70%:wrap,<120(right,50%,wrap)" \
            --bind="enter:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git show --color=always | less -R < /dev/tty > /dev/tty)" \
            --bind="alt-e:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git show | nvim -c 'set ft=git' - < /dev/tty > /dev/tty)" \
            --bind="alt-c:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git checkout < /dev/tty > /dev/tty)+abort" \
            --bind="alt-r:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git reset --hard < /dev/tty > /dev/tty)+abort" \
            --bind="alt-i:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs -I{} sh -c 'git rebase -i {}^' < /dev/tty > /dev/tty)+abort" \
            --bind="alt-p:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git cherry-pick < /dev/tty > /dev/tty)+reload(git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%cd %h%d %s (%an)')" \
            --bind="alt-f:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs -I{} sh -c 'git commit --fixup={} && GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash {}^' < /dev/tty > /dev/tty)+abort" \
            --bind="alt-s:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs -I{} sh -c 'git commit --squash={} && GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash {}^' < /dev/tty > /dev/tty)+abort" \
            --bind="alt-w:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs -I{} sh -c 'git commit --fixup=reword:{} && GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash {}^' < /dev/tty > /dev/tty)+abort" \
            --bind="alt-v:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git revert < /dev/tty > /dev/tty)+abort" \
            --bind="ctrl-/:toggle-preview" \
            --bind="ctrl-y:preview-up" \
            --bind="ctrl-e:preview-down" \
            --bind="ctrl-u:preview-half-page-up" \
            --bind="ctrl-d:preview-half-page-down"
    )

    if test -n "$selected"
        # Extract commit hashes from all selected items and insert into command line
        set -l hashes
        for line in $selected
            set -l hash (echo $line | grep -o '[a-f0-9]\{7,\}' | head -n1)
            set -a hashes $hash
        end
        commandline -i (string join ' ' $hashes)" "
    end
end

# Git Branches Interface - Operations on Branches (multi-select enabled)
function _git_fzf_branch_actions
    # Check if in git repo
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end

    set -l current_branch (git rev-parse --abbrev-ref HEAD)

    set -l selected (
        git branch --all --sort=-committerdate --color=always \
            --format='%(if)%(HEAD)%(then)* %(else)  %(end)%(color:yellow)%(refname:short)%(color:reset) %(color:green)(%(committerdate:relative))%(color:reset) %(color:blue)%(subject)%(color:reset)' | \
        fzf --ansi \
            --multi \
            --bind 'tab:toggle+down,shift-tab:toggle+up' \
            --border-label="🌳 Git Branches (Current: $current_branch)" \
            --header="ALT-E (nvim) | ALT-C (checkout) | ALT-M (merge) | ALT-R (rebase) | ALT-X (delete) | ALT-D/L (diff/log) | CTRL-/ (preview)" \
            --preview="echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs -I{} git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%cd %h%d %s' {} --" \
            --preview-window="right:70%:wrap,<120(right,50%,wrap)" \
            --bind="alt-e:execute(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs -I{} git diff $current_branch...{} | nvim -c 'set ft=diff' - < /dev/tty > /dev/tty)" \
            --bind="alt-c:execute(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs git checkout < /dev/tty > /dev/tty)+abort" \
            --bind="alt-m:execute(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs git merge < /dev/tty > /dev/tty)+abort" \
            --bind="alt-r:execute(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs git rebase < /dev/tty > /dev/tty)+abort" \
            --bind="alt-x:execute(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs git branch -d < /dev/tty > /dev/tty)+reload(git branch --all --sort=-committerdate --color=always --format='%(if)%(HEAD)%(then)* %(else)  %(end)%(color:yellow)%(refname:short)%(color:reset) %(color:green)(%(committerdate:relative))%(color:reset) %(color:blue)%(subject)%(color:reset)')" \
            --bind="alt-d:change-preview(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs -I{} git diff --color=always $current_branch...{})" \
            --bind="alt-l:change-preview(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs -I{} git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%cd %h%d %s' {} --)" \
            --bind="ctrl-/:toggle-preview" \
            --bind="ctrl-y:preview-up" \
            --bind="ctrl-e:preview-down" \
            --bind="ctrl-u:preview-half-page-up" \
            --bind="ctrl-d:preview-half-page-down"
    )

    if test -n "$selected"
        # Extract branch names from all selected items and insert into command line
        set -l branches
        for line in $selected
            set -l branch (echo $line | awk '{print $1}' | sed 's/^[* ]*//')
            set -a branches $branch
        end
        commandline -i (string join ' ' $branches)" "
    end
end

# Git Clean Interface - Untracked File Actions
function _git_fzf_clean_actions
    # Check if in git repo
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end

    set -l untracked (git clean -n -d 2>/dev/null | sed 's/^Would remove //')
    if test -z "$untracked"
        echo "No untracked files to clean"
        return 0
    end

    set -l selected (
        printf '%s\n' $untracked | \
        fzf --ansi \
            --multi \
            --bind 'tab:toggle+down,shift-tab:toggle+up' \
            --border-label="🧹 Git Clean (Untracked Files)" \
            --header="ENTER (delete) | ALT-D (dry-run) | ALT-A (delete all) | CTRL-/ (preview)" \
            --preview="test -d {} && tree -C {} 2>/dev/null || bat --color=always {} 2>/dev/null || cat {}" \
            --preview-window="right:60%:wrap" \
            --bind="alt-d:execute(git clean -n -d < /dev/tty > /dev/tty)" \
            --bind="alt-a:execute(git clean -fd < /dev/tty > /dev/tty)+abort" \
            --bind="ctrl-/:toggle-preview"
    )

    if test -n "$selected"
        for item in $selected
            git clean -f -- "$item"
            echo "Removed: $item"
        end
    end
end
