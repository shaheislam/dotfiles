# Git FZF Action-Based Workflows
# Inspired by https://thevaluable.dev/fzf-git-integration/
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
            --header="ALT-P (patch add) | ALT-D (discard) | ALT-C (commit) | ALT-A (amend) | ALT-E (edit)" \
            --preview="echo {} | awk '{print \$2}' | xargs git diff --color=always -- 2>/dev/null || echo {} | awk '{print \$2}' | xargs bat --color=always" \
            --preview-window="right:60%" \
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

# Git Commits Interface - Operations on Commits
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
            --border-label="🍡 Git Commits" \
            --header="ENTER (show) | ALT-C (checkout) | ALT-R (reset) | ALT-I (rebase) | ALT-P (cherry-pick)" \
            --preview="echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git show --color=always" \
            --preview-window="right:60%" \
            --bind="enter:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git show --color=always | less -R < /dev/tty > /dev/tty)" \
            --bind="alt-c:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git checkout < /dev/tty > /dev/tty)+abort" \
            --bind="alt-r:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git reset --hard < /dev/tty > /dev/tty)+abort" \
            --bind="alt-i:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs -I{} sh -c 'git rebase -i {}^' < /dev/tty > /dev/tty)+abort" \
            --bind="alt-p:execute(echo {} | grep -o '[a-f0-9]\{7,\}' | head -n1 | xargs git cherry-pick < /dev/tty > /dev/tty)+reload(git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%cd %h%d %s (%an)')" \
            --bind="ctrl-/:toggle-preview" \
            --bind="ctrl-y:preview-up" \
            --bind="ctrl-e:preview-down" \
            --bind="ctrl-u:preview-half-page-up" \
            --bind="ctrl-d:preview-half-page-down"
    )

    if test -n "$selected"
        # Extract commit hash and insert into command line
        set -l hash (echo $selected | grep -o '[a-f0-9]\{7,\}' | head -n1)
        commandline -i $hash
    end
end

# Git Branches Interface - Operations on Branches
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
            --border-label="🌳 Git Branches (Current: $current_branch)" \
            --header="ALT-C (checkout) | ALT-M (merge) | ALT-R (rebase) | ALT-D (diff) | ALT-L (log)" \
            --preview="echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs -I{} git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%cd %h%d %s' {} --" \
            --preview-window="right:60%" \
            --bind="alt-c:execute(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs git checkout < /dev/tty > /dev/tty)+abort" \
            --bind="alt-m:execute(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs git merge < /dev/tty > /dev/tty)+abort" \
            --bind="alt-r:execute(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs git rebase < /dev/tty > /dev/tty)+abort" \
            --bind="alt-d:change-preview(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs -I{} git diff --color=always $current_branch...{})" \
            --bind="alt-l:change-preview(echo {} | awk '{print \$1}' | sed 's/^[* ]*//' | xargs -I{} git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%cd %h%d %s' {} --)" \
            --bind="ctrl-/:toggle-preview" \
            --bind="ctrl-y:preview-up" \
            --bind="ctrl-e:preview-down" \
            --bind="ctrl-u:preview-half-page-up" \
            --bind="ctrl-d:preview-half-page-down"
    )

    if test -n "$selected"
        # Extract branch name and insert into command line
        set -l branch (echo $selected | awk '{print $1}' | sed 's/^[* ]*//')
        commandline -i $branch
    end
end
