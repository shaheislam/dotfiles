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
    set -l cmd (commandline -opc) 2>/dev/null

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
    set -l cmd (commandline -opc) 2>/dev/null

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

# Show modified/staged/untracked files for git add
complete -c git -n '__fish_git_using_command add' -a '
    (
        # Show modified and untracked files
        git status --porcelain 2>/dev/null | \
        sed -n "s/^\\([ MADRCU?!][ MADRCU?!]\\) \\(.*\\)/\\2/p"
    )
' -d 'Modified/Untracked file'

# Common flags for git add
complete -c git -n '__fish_git_using_command add' -s p -l patch -d 'Interactively select hunks'
complete -c git -n '__fish_git_using_command add' -s A -l all -d 'Add all tracked files'
complete -c git -n '__fish_git_using_command add' -s u -l update -d 'Add modified tracked files'
complete -c git -n '__fish_git_using_command add' -s n -l dry-run -d 'Show what would be added'
complete -c git -n '__fish_git_using_command add' -s v -l verbose -d 'Be verbose'

# =============================================================================
# git branch - Show branches and common operations
# =============================================================================
complete -c git -n '__fish_git_using_command branch' -f

# Show local branches
complete -c git -n '__fish_git_using_command branch; and not __fish_seen_argument -r --remote -a --all' -a '
    (
        git branch --format="%(refname:short)" 2>/dev/null
    )
' -d 'Local branch'

# Show remote branches when -r is used
complete -c git -n '__fish_git_using_command branch; and __fish_seen_argument -r --remote' -a '
    (
        git branch -r --format="%(refname:short)" 2>/dev/null | sed "s/^origin\\///"
    )
' -d 'Remote branch'

# Common branch flags
complete -c git -n '__fish_git_using_command branch' -s d -l delete -d 'Delete a branch'
complete -c git -n '__fish_git_using_command branch' -s D -d 'Force delete a branch'
complete -c git -n '__fish_git_using_command branch' -s r -l remote -d 'List remote branches'
complete -c git -n '__fish_git_using_command branch' -s a -l all -d 'List all branches'
complete -c git -n '__fish_git_using_command branch' -s m -l move -d 'Rename branch'

# =============================================================================
# git checkout - Show branches and files
# =============================================================================
complete -c git -n '__fish_git_using_command checkout' -f

# Show branches for checkout
complete -c git -n '__fish_git_using_command checkout; and not __fish_seen_argument -- -b' -a '
    (
        # Local branches
        git branch --format="%(refname:short)" 2>/dev/null
        # Remote branches (without origin prefix for easier checkout)
        git branch -r --format="%(refname:short)" 2>/dev/null | sed "s/^origin\\///" | grep -v HEAD
    )
' -d 'Branch'

# Show modified files after -- separator
complete -c git -n '__fish_git_using_command checkout; and __fish_seen_argument --' -a '
    (
        git diff --name-only 2>/dev/null
    )
' -d 'Modified file'

# Common checkout flags
complete -c git -n '__fish_git_using_command checkout' -s b -d 'Create and checkout new branch'
complete -c git -n '__fish_git_using_command checkout' -s B -d 'Force create and checkout branch'
complete -c git -n '__fish_git_using_command checkout' -l track -d 'Set upstream branch'

# =============================================================================
# git commit - Common flags and options
# =============================================================================
complete -c git -n '__fish_git_using_command commit' -s m -l message -d 'Commit message' -x
complete -c git -n '__fish_git_using_command commit' -s a -l all -d 'Stage all modified files'
complete -c git -n '__fish_git_using_command commit' -l amend -d 'Amend previous commit'
complete -c git -n '__fish_git_using_command commit' -s v -l verbose -d 'Show diff in editor'
complete -c git -n '__fish_git_using_command commit' -l no-verify -d 'Skip hooks'
complete -c git -n '__fish_git_using_command commit' -s S -l gpg-sign -d 'GPG sign commit'

# =============================================================================
# git diff - Show files and commits
# =============================================================================
complete -c git -n '__fish_git_using_command diff' -f

# Show branches and commits for comparison
complete -c git -n '__fish_git_using_command diff; and test (count (commandline -opc)) -le 3' -a '
    (
        # Recent commits
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
        # Branches
        git branch --format="%(refname:short)" 2>/dev/null
    )
' -d 'Commit/Branch'

# Show files that have differences
complete -c git -n '__fish_git_using_command diff' -a '
    (
        # Show all files with differences
        git diff --name-only 2>/dev/null
        git diff --cached --name-only 2>/dev/null
    )
' -d 'File with changes'

# Common diff flags
complete -c git -n '__fish_git_using_command diff' -l staged -l cached -d 'Show staged changes'
complete -c git -n '__fish_git_using_command diff' -l stat -d 'Show diffstat only'
complete -c git -n '__fish_git_using_command diff' -l name-only -d 'Show only filenames'

# =============================================================================
# git log - Show recent commits and branches
# =============================================================================
complete -c git -n '__fish_git_using_command log' -f

# Show branches for log
complete -c git -n '__fish_git_using_command log' -a '
    (
        git branch --format="%(refname:short)" 2>/dev/null
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
    )
' -d 'Branch/Commit'

# Common log flags
complete -c git -n '__fish_git_using_command log' -l oneline -d 'One line per commit'
complete -c git -n '__fish_git_using_command log' -l graph -d 'Show commit graph'
complete -c git -n '__fish_git_using_command log' -s p -l patch -d 'Show patches'
complete -c git -n '__fish_git_using_command log' -l stat -d 'Show stats'
complete -c git -n '__fish_git_using_command log' -s n -l max-count -d 'Limit number of commits' -x

# =============================================================================
# git merge - Show branches to merge
# =============================================================================
complete -c git -n '__fish_git_using_command merge' -f

complete -c git -n '__fish_git_using_command merge' -a '
    (
        git branch --format="%(refname:short)" 2>/dev/null
        git branch -r --format="%(refname:short)" 2>/dev/null | sed "s/^origin\\///"
    )
' -d 'Branch to merge'

# Common merge flags
complete -c git -n '__fish_git_using_command merge' -l no-ff -d 'No fast-forward merge'
complete -c git -n '__fish_git_using_command merge' -l squash -d 'Squash commits'
complete -c git -n '__fish_git_using_command merge' -l abort -d 'Abort merge'

# =============================================================================
# git rebase - Show branches to rebase onto
# =============================================================================
complete -c git -n '__fish_git_using_command rebase' -f

complete -c git -n '__fish_git_using_command rebase' -a '
    (
        git branch --format="%(refname:short)" 2>/dev/null
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
    )
' -d 'Branch/Commit'

complete -c git -n '__fish_git_using_command rebase' -s i -l interactive -d 'Interactive rebase'
complete -c git -n '__fish_git_using_command rebase' -l continue -d 'Continue rebase'
complete -c git -n '__fish_git_using_command rebase' -l abort -d 'Abort rebase'
complete -c git -n '__fish_git_using_command rebase' -l skip -d 'Skip current commit'

# =============================================================================
# git reset - Show files and commits
# =============================================================================
complete -c git -n '__fish_git_using_command reset' -f

# Show commits for reset operations with --hard/--soft/--mixed
complete -c git -n '__fish_git_using_command reset; and __fish_seen_argument --hard --soft --mixed' -a '
    (
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
    )
' -d 'Commit'

# Show files for reset without mode flags
complete -c git -n '__fish_git_using_command reset; and not __fish_seen_argument --hard --soft --mixed' -a '
    (
        git diff --cached --name-only 2>/dev/null
    )
' -d 'Staged file'

complete -c git -n '__fish_git_using_command reset' -l hard -d 'Reset working tree and index'
complete -c git -n '__fish_git_using_command reset' -l soft -d 'Keep working tree and index'
complete -c git -n '__fish_git_using_command reset' -l mixed -d 'Reset index, keep working tree'

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

# Common push flags
complete -c git -n '__fish_git_using_command push' -s f -l force -d 'Force push'
complete -c git -n '__fish_git_using_command push' -l force-with-lease -d 'Safe force push'
complete -c git -n '__fish_git_using_command push' -s u -l set-upstream -d 'Set upstream'
complete -c git -n '__fish_git_using_command push' -l tags -d 'Push tags'
complete -c git -n '__fish_git_using_command push' -l all -d 'Push all branches'

# =============================================================================
# git pull - Show remotes and branches
# =============================================================================
complete -c git -n '__fish_git_using_command pull' -f

# Show remotes for pull
complete -c git -n '__fish_git_using_command pull; and test (count (commandline -opc)) -eq 2' -a '
    (
        git remote 2>/dev/null
    )
' -d 'Remote'

# Show branches after remote
complete -c git -n '__fish_git_using_command pull; and test (count (commandline -opc)) -eq 3' -a '
    (
        git branch -r --format="%(refname:short)" 2>/dev/null | grep "^$argv[1]/" | sed "s/^$argv[1]\\///"
    )
' -d 'Remote branch'

complete -c git -n '__fish_git_using_command pull' -l rebase -d 'Rebase instead of merge'
complete -c git -n '__fish_git_using_command pull' -l no-rebase -d 'Merge instead of rebase'

# =============================================================================
# git fetch - Show remotes
# =============================================================================
complete -c git -n '__fish_git_using_command fetch' -f
complete -c git -n '__fish_git_using_command fetch' -a '
    (
        git remote 2>/dev/null
    )
' -d 'Remote'

complete -c git -n '__fish_git_using_command fetch' -l all -d 'Fetch all remotes'
complete -c git -n '__fish_git_using_command fetch' -l prune -d 'Prune deleted branches'

# =============================================================================
# git remote - Show remotes for subcommands
# =============================================================================
complete -c git -n '__fish_git_using_command remote' -a 'add remove rm rename show prune' -d 'Subcommand'

# Show existing remotes for operations like remove, rename, show
complete -c git -n '__fish_git_using_command remote; and __fish_seen_argument remove rm rename show prune' -a '
    (
        git remote 2>/dev/null
    )
' -d 'Remote'

# =============================================================================
# git stash - Stash operations
# =============================================================================
complete -c git -n '__fish_git_using_command stash' -a 'push pop apply drop list show clear' -d 'Subcommand'

# Show stash entries for pop, apply, drop, show
complete -c git -n '__fish_git_using_command stash; and __fish_seen_argument pop apply drop show' -a '
    (
        git stash list 2>/dev/null | sed "s/:.*//g"
    )
' -d 'Stash entry'

# =============================================================================
# git tag - Tag operations
# =============================================================================
complete -c git -n '__fish_git_using_command tag' -f

# Show existing tags for deletion
complete -c git -n '__fish_git_using_command tag; and __fish_seen_argument -d --delete' -a '
    (
        git tag 2>/dev/null
    )
' -d 'Tag'

complete -c git -n '__fish_git_using_command tag' -s a -l annotate -d 'Annotated tag'
complete -c git -n '__fish_git_using_command tag' -s d -l delete -d 'Delete tag'
complete -c git -n '__fish_git_using_command tag' -s l -l list -d 'List tags'

# =============================================================================
# Common git subcommands
# =============================================================================
complete -c git -n 'test (count (commandline -opc)) -eq 1' -a 'add branch checkout cherry-pick clone commit diff fetch init log merge pull push rebase reset restore revert rm show stash status switch tag' -d 'Command'