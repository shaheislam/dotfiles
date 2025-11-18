# Custom git completions for enhanced FZF-powered git workflow
# Works alongside fzf-git.sh keybindings (CTRL-G CTRL-X)
# Provides tab completion for natural git CLI usage

# Erase any existing generic git completions that might interfere
complete -c git -e

# =============================================================================
# Helper Functions
# =============================================================================

# Check if we're completing a specific git subcommand
function __fish_git_using_command
    set -l cmd (commandline -opc)

    # Check if git is the first command
    if test (count $cmd) -lt 2
        return 1
    end

    if test $cmd[1] != 'git'
        return 1
    end

    # Check if the second argument matches the requested subcommand
    if test $cmd[2] = $argv[1]
        return 0
    end

    return 1
end

# Check if a specific argument has been seen
function __fish_seen_argument
    set -l cmd (commandline -opc)

    for arg in $argv
        if contains -- $arg $cmd
            return 0
        end
    end

    return 1
end

# =============================================================================
# git add - Show only uncommitted files (modified, untracked, deleted)
# =============================================================================

# First, explicitly prevent any file completions for git add
complete -c git -n '__fish_git_using_command add' -f

# Then add our custom completion for uncommitted files only
complete -c git -n '__fish_git_using_command add' -a '
    (
        git status --porcelain 2>/dev/null | while read -l status_line
            set -l file_path (string sub -s 4 -- $status_line)
            # Handle renamed files (format: "old -> new")
            if string match -q "* -> *" -- $file_path
                set file_path (string split " -> " -- $file_path)[2]
            end
            echo $file_path
        end
    )
' -d 'Uncommitted file'

# =============================================================================
# git rm - Show only tracked files
# =============================================================================
complete -c git -n '__fish_git_using_command rm' -f
complete -c git -n '__fish_git_using_command rm' -a '
    (
        git ls-files 2>/dev/null
    )
' -d 'Tracked file'

# =============================================================================
# git restore - Show modified files (staged and unstaged)
# =============================================================================
complete -c git -n '__fish_git_using_command restore' -f
complete -c git -n '__fish_git_using_command restore' -a '
    (
        git status --porcelain 2>/dev/null | while read -l status_line
            set -l status (string sub -l 2 -- $status_line | string trim)
            # Only show modified files (M), deleted (D), or staged files
            if string match -qr '^[MD ]' -- $status
                set -l file_path (string sub -s 4 -- $status_line)
                if string match -q "* -> *" -- $file_path
                    set file_path (string split " -> " -- $file_path)[2]
                end
                echo $file_path
            end
        end
    )
' -d 'Modified file'

# =============================================================================
# git checkout - Show branches (context-aware)
# When used without file paths, show branches
# =============================================================================
complete -c git -n '__fish_git_using_command checkout; and not __fish_seen_argument -b' -f
complete -c git -n '__fish_git_using_command checkout; and not __fish_seen_argument -b' -a '
    (
        # Show local and remote branches
        git branch -a --format="%(refname:short)" 2>/dev/null | string replace "origin/" ""
    )
' -d 'Branch'

# =============================================================================
# git switch - Show all branches (local + remote)
# =============================================================================
complete -c git -n '__fish_git_using_command switch; and not __fish_seen_argument -c' -f
complete -c git -n '__fish_git_using_command switch; and not __fish_seen_argument -c' -a '
    (
        git branch -a --format="%(refname:short)" 2>/dev/null | string replace "origin/" ""
    )
' -d 'Branch'

# =============================================================================
# git branch -d/-D - Show local branches (exclude current branch)
# =============================================================================
complete -c git -n '__fish_git_using_command branch; and __fish_seen_argument -d -D' -f
complete -c git -n '__fish_git_using_command branch; and __fish_seen_argument -d -D' -a '
    (
        set -l current_branch (git branch --show-current 2>/dev/null)
        git branch --format="%(refname:short)" 2>/dev/null | while read -l branch
            # Exclude current branch from deletion suggestions
            if test "$branch" != "$current_branch"
                echo $branch
            end
        end
    )
' -d 'Local branch'

# =============================================================================
# git merge - Show branches to merge into current
# =============================================================================
complete -c git -n '__fish_git_using_command merge' -f
complete -c git -n '__fish_git_using_command merge' -a '
    (
        set -l current_branch (git branch --show-current 2>/dev/null)
        git branch -a --format="%(refname:short)" 2>/dev/null | while read -l branch
            # Exclude current branch
            if test "$branch" != "$current_branch"
                echo (string replace "origin/" "" -- $branch)
            end
        end
    )
' -d 'Branch to merge'

# =============================================================================
# git reset - Show staged and modified files
# =============================================================================
complete -c git -n '__fish_git_using_command reset; and not __fish_seen_argument --hard --soft --mixed' -f
complete -c git -n '__fish_git_using_command reset; and not __fish_seen_argument --hard --soft --mixed' -a '
    (
        # Show files that are staged or modified
        git diff --name-only --cached 2>/dev/null
        git diff --name-only 2>/dev/null
    )
' -d 'File to unstage'

# =============================================================================
# git reset --hard/--soft/--mixed - Show commit references
# =============================================================================
complete -c git -n '__fish_git_using_command reset; and __fish_seen_argument --hard --soft --mixed' -f
complete -c git -n '__fish_git_using_command reset; and __fish_seen_argument --hard --soft --mixed' -a '
    (
        # Show recent commits
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
    )
' -d 'Commit'

# =============================================================================
# git push - Show remotes, then branches
# =============================================================================
complete -c git -n '__fish_git_using_command push' -f

# First argument: show remotes
complete -c git -n '__fish_git_using_command push; and test (count (commandline -opc)) -eq 2' -a '
    (
        git remote 2>/dev/null
    )
' -d 'Remote'

# Second argument: show local branches after remote is specified
complete -c git -n '__fish_git_using_command push; and test (count (commandline -opc)) -eq 3' -a '
    (
        git branch --format="%(refname:short)" 2>/dev/null
    )
' -d 'Local branch'

# =============================================================================
# git pull - Show remotes, then remote branches
# =============================================================================
complete -c git -n '__fish_git_using_command pull' -f

# First argument: show remotes
complete -c git -n '__fish_git_using_command pull; and test (count (commandline -opc)) -eq 2' -a '
    (
        git remote 2>/dev/null
    )
' -d 'Remote'

# Second argument: show remote branches after remote is specified
complete -c git -n '__fish_git_using_command pull; and test (count (commandline -opc)) -eq 3' -a '
    (
        set -l remote (commandline -opc)[-1]
        git branch -r --format="%(refname:short)" 2>/dev/null | string match "$remote/*" | string replace "$remote/" ""
    )
' -d 'Remote branch'

# =============================================================================
# git fetch - Show remotes
# =============================================================================
complete -c git -n '__fish_git_using_command fetch' -f
complete -c git -n '__fish_git_using_command fetch' -a '
    (
        git remote 2>/dev/null
    )
' -d 'Remote'

# =============================================================================
# git stash - Show stash operations and entries
# =============================================================================
complete -c git -n '__fish_git_using_command stash' -f

# git stash pop/apply/drop/show/branch - Show stash entries
complete -c git -n '__fish_git_using_command stash; and __fish_seen_argument pop apply drop show branch' -a '
    (
        git stash list --format="%gd" 2>/dev/null
    )
' -d 'Stash entry'

# =============================================================================
# git rebase - Show branches to rebase onto
# =============================================================================
complete -c git -n '__fish_git_using_command rebase' -f
complete -c git -n '__fish_git_using_command rebase; and not __fish_seen_argument -i --interactive' -a '
    (
        set -l current_branch (git branch --show-current 2>/dev/null)
        git branch -a --format="%(refname:short)" 2>/dev/null | while read -l branch
            # Exclude current branch
            if test "$branch" != "$current_branch"
                echo (string replace "origin/" "" -- $branch)
            end
        end
    )
' -d 'Branch to rebase onto'

# git rebase -i/--interactive - Show commits for interactive rebase
complete -c git -n '__fish_git_using_command rebase; and __fish_seen_argument -i --interactive' -a '
    (
        # Show recent commits
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
    )
' -d 'Commit'

# =============================================================================
# git cherry-pick - Show commits to cherry-pick
# =============================================================================
complete -c git -n '__fish_git_using_command cherry-pick' -f
complete -c git -n '__fish_git_using_command cherry-pick' -a '
    (
        # Show recent commits from all branches
        git log --all --oneline --max-count=50 --format="%h" 2>/dev/null
    )
' -d 'Commit to cherry-pick'

# =============================================================================
# git revert - Show commits to revert
# =============================================================================
complete -c git -n '__fish_git_using_command revert' -f
complete -c git -n '__fish_git_using_command revert' -a '
    (
        # Show recent commits
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
    )
' -d 'Commit to revert'

# =============================================================================
# git show - Show commits, branches, or tags
# =============================================================================
complete -c git -n '__fish_git_using_command show' -f
complete -c git -n '__fish_git_using_command show' -a '
    (
        # Show recent commits
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
        # Show branches
        git branch -a --format="%(refname:short)" 2>/dev/null | string replace "origin/" ""
        # Show tags
        git tag 2>/dev/null
    )
' -d 'Commit/Branch/Tag'

# =============================================================================
# git tag -d - Show tags for deletion
# =============================================================================
complete -c git -n '__fish_git_using_command tag; and __fish_seen_argument -d --delete' -f
complete -c git -n '__fish_git_using_command tag; and __fish_seen_argument -d --delete' -a '
    (
        git tag 2>/dev/null
    )
' -d 'Tag to delete'

# =============================================================================
# git remote - Show remote operations and names
# =============================================================================
complete -c git -n '__fish_git_using_command remote' -f

# git remote remove/show/prune/get-url - Show remote names
complete -c git -n '__fish_git_using_command remote; and __fish_seen_argument remove rm show prune get-url set-url' -a '
    (
        git remote 2>/dev/null
    )
' -d 'Remote name'

# =============================================================================
# git diff - Context-aware (branches, commits, or staged files)
# =============================================================================
complete -c git -n '__fish_git_using_command diff' -f
complete -c git -n '__fish_git_using_command diff; and not __fish_seen_argument --cached --staged' -a '
    (
        # Show branches for comparison
        git branch -a --format="%(refname:short)" 2>/dev/null | string replace "origin/" ""
        # Show recent commits
        git log --oneline --max-count=10 --format="%h" 2>/dev/null
        # Show tags
        git tag 2>/dev/null
    )
' -d 'Branch/Commit/Tag'

# git diff --cached/--staged - Show staged files
complete -c git -n '__fish_git_using_command diff; and __fish_seen_argument --cached --staged' -a '
    (
        git diff --name-only --cached 2>/dev/null
    )
' -d 'Staged file'

# =============================================================================
# git log - Show branches/tags as starting points
# =============================================================================
complete -c git -n '__fish_git_using_command log' -f
complete -c git -n '__fish_git_using_command log' -a '
    (
        # Show branches
        git branch -a --format="%(refname:short)" 2>/dev/null | string replace "origin/" ""
        # Show tags
        git tag 2>/dev/null
    )
' -d 'Branch/Tag'

# =============================================================================
# git worktree - Show worktree operations
# =============================================================================
complete -c git -n '__fish_git_using_command worktree' -f

# git worktree remove - Show worktrees
complete -c git -n '__fish_git_using_command worktree; and __fish_seen_argument remove' -a '
    (
        git worktree list --porcelain 2>/dev/null | grep '^worktree' | cut -d' ' -f2
    )
' -d 'Worktree path'
