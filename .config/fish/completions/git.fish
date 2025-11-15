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
