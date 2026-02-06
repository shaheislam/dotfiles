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
complete -c git -n '__fish_git_using_command commit' -l fixup -d 'Fixup commit for rebase' -x
complete -c git -n '__fish_git_using_command commit' -l squash -d 'Squash commit for rebase' -x

# Show recent commits for --fixup/--squash
complete -c git -n '__fish_git_using_command commit; and __fish_seen_argument --fixup --squash' -a '
    (
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
    )
' -d 'Recent commit'

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
# git show - Show various types of objects
# =============================================================================
complete -c git -n '__fish_git_using_command show' -f

# Show commits by default
complete -c git -n '__fish_git_using_command show; and not __fish_seen_argument --stat --name-only' -a '
    (
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
        git branch --format="%(refname:short)" 2>/dev/null
        git tag 2>/dev/null
    )
' -d 'Commit/Branch/Tag'

# Common show flags
complete -c git -n '__fish_git_using_command show' -l stat -d 'Show diffstat'
complete -c git -n '__fish_git_using_command show' -l name-only -d 'Show only filenames'
complete -c git -n '__fish_git_using_command show' -l pretty -d 'Format output' -x
complete -c git -n '__fish_git_using_command show' -l oneline -d 'One line per commit'

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
# git merge-base - Find common ancestor
# =============================================================================
complete -c git -n '__fish_git_using_command merge-base' -f

# Flags
complete -c git -n '__fish_git_using_command merge-base' -l is-ancestor -d 'Check if first commit is ancestor of second'
complete -c git -n '__fish_git_using_command merge-base' -l fork-point -d 'Find fork point'
complete -c git -n '__fish_git_using_command merge-base' -l octopus -d 'Compute merge bases for octopus merge'
complete -c git -n '__fish_git_using_command merge-base' -l all -d 'Show all common ancestors'

# After --is-ancestor: first arg = commit (hashes)
complete -c git -n '__fish_git_using_command merge-base; and __fish_seen_argument --is-ancestor; and test (count (commandline -opc)) -eq 4' -a '
    (
        git log --oneline --max-count=30 --format="%h" 2>/dev/null
    )
' -d 'Commit'

# After --is-ancestor: second arg = branch
complete -c git -n '__fish_git_using_command merge-base; and __fish_seen_argument --is-ancestor; and test (count (commandline -opc)) -eq 5' -a '
    (
        git branch --format="%(refname:short)" 2>/dev/null
        git branch -r --format="%(refname:short)" 2>/dev/null | sed "s/^origin\\///"
    )
' -d 'Branch'

# Without --is-ancestor: show commits and branches for both args
complete -c git -n '__fish_git_using_command merge-base; and not __fish_seen_argument --is-ancestor' -a '
    (
        git log --oneline --max-count=20 --format="%h" 2>/dev/null
        git branch --format="%(refname:short)" 2>/dev/null
    )
' -d 'Commit/Branch'

# =============================================================================
# git rebase - Show branches to rebase onto
# =============================================================================
complete -c git -n '__fish_git_using_command rebase' -f

complete -c git -n '__fish_git_using_command rebase' -a '
    (
        # Local branches
        git branch --format="%(refname:short)" 2>/dev/null
        # Remote branches with full paths (e.g., origin/main)
        git branch -r --format="%(refname:short)" 2>/dev/null | grep -v HEAD
        # Recent commits
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
# git rm - Show tracked files for removal
# =============================================================================
complete -c git -n '__fish_git_using_command rm' -f

# Show tracked files (with relative paths that work from any subdirectory)
complete -c git -n '__fish_git_using_command rm' -a '
    (
        set -l cdup (git rev-parse --show-cdup 2>/dev/null)
        git ls-files --full-name :/ 2>/dev/null | sed "s|^|$cdup|"
    )
' -d 'Tracked file'

# Common rm flags
complete -c git -n '__fish_git_using_command rm' -l cached -d 'Remove from index only'
complete -c git -n '__fish_git_using_command rm' -s f -l force -d 'Force removal'
complete -c git -n '__fish_git_using_command rm' -s r -d 'Allow recursive removal'
complete -c git -n '__fish_git_using_command rm' -s n -l dry-run -d 'Show what would be removed'
complete -c git -n '__fish_git_using_command rm' -l quiet -d 'Suppress output'

# =============================================================================
# git restore - Show files for restoring
# =============================================================================
complete -c git -n '__fish_git_using_command restore' -f

# Show modified files for restore (unstaged changes)
complete -c git -n '__fish_git_using_command restore; and not __fish_seen_argument --staged -S --source -s' -a '
    (
        git diff --name-only 2>/dev/null
    )
' -d 'Modified file'

# Show staged files for restore --staged
complete -c git -n '__fish_git_using_command restore; and __fish_seen_argument --staged -S' -a '
    (
        git diff --cached --name-only 2>/dev/null
    )
' -d 'Staged file'

# Common restore flags
complete -c git -n '__fish_git_using_command restore' -s S -l staged -d 'Restore staged changes'
complete -c git -n '__fish_git_using_command restore' -s s -l source -d 'Restore from source' -x
complete -c git -n '__fish_git_using_command restore' -s p -l patch -d 'Interactively select hunks'
complete -c git -n '__fish_git_using_command restore' -l ours -d 'Restore ours version'
complete -c git -n '__fish_git_using_command restore' -l theirs -d 'Restore theirs version'

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
# git worktree - Worktree operations
# =============================================================================
complete -c git -n '__fish_git_using_command worktree' -f

# Subcommands
complete -c git -n '__fish_git_using_command worktree; and test (count (commandline -opc)) -eq 2' \
    -a 'add list lock move prune remove repair unlock' -d 'Worktree operation'

# Show existing worktrees for operations like remove, move, lock, unlock, repair
complete -c git -n '__fish_git_using_command worktree; and __fish_seen_argument remove move lock unlock repair' -a '
    (
        git worktree list --porcelain 2>/dev/null | grep "^worktree" | cut -d" " -f2
    )
' -d 'Worktree path'

# Show branches for 'worktree add' when path already specified
complete -c git -n '__fish_git_using_command worktree; and __fish_seen_argument add; and test (count (commandline -opc)) -ge 3' -a '
    (
        git branch --format="%(refname:short)" 2>/dev/null
    )
' -d 'Branch'

# Common flags for 'worktree add'
complete -c git -n '__fish_git_using_command worktree; and __fish_seen_argument add' -s b -d 'Create new branch'
complete -c git -n '__fish_git_using_command worktree; and __fish_seen_argument add' -s B -d 'Create/reset branch'
complete -c git -n '__fish_git_using_command worktree; and __fish_seen_argument add' -l detach -d 'Detach HEAD'

# Common flags for 'worktree list'
complete -c git -n '__fish_git_using_command worktree; and __fish_seen_argument list' -l porcelain -d 'Machine-readable output'
complete -c git -n '__fish_git_using_command worktree; and __fish_seen_argument list' -s v -l verbose -d 'Show additional info'

# =============================================================================
# git reflog - Reflog operations
# =============================================================================
complete -c git -n '__fish_git_using_command reflog' -f
complete -c git -n '__fish_git_using_command reflog' -a 'show delete expire' -d 'Reflog subcommand'
complete -c git -n '__fish_git_using_command reflog' -l all -d 'Show all refs'

# =============================================================================
# git bisect - Binary search for bugs
# =============================================================================
complete -c git -n '__fish_git_using_command bisect' -f
complete -c git -n '__fish_git_using_command bisect' -a 'start bad good skip reset visualize replay log run' -d 'Bisect subcommand'

# =============================================================================
# git blame - Show what revision and author last modified each line
# =============================================================================
complete -c git -n '__fish_git_using_command blame' -f
complete -c git -n '__fish_git_using_command blame' -s L -d 'Annotate only given line range' -x
complete -c git -n '__fish_git_using_command blame' -s C -d 'Detect lines moved/copied'
complete -c git -n '__fish_git_using_command blame' -l show-email -d 'Show author email'

# =============================================================================
# git cherry - Find commits not merged upstream
# =============================================================================
complete -c git -n '__fish_git_using_command cherry' -f
complete -c git -n '__fish_git_using_command cherry' -s v -d 'Show commit subjects'
complete -c git -n '__fish_git_using_command cherry' -a '
    (
        git branch --format="%(refname:short)" 2>/dev/null
    )
' -d 'Branch'

# =============================================================================
# git submodule - Submodule operations
# =============================================================================
complete -c git -n '__fish_git_using_command submodule' -f
complete -c git -n '__fish_git_using_command submodule; and test (count (commandline -opc)) -eq 2' \
    -a 'add update init deinit foreach status summary sync' -d 'Submodule operation'
complete -c git -n '__fish_git_using_command submodule; and __fish_seen_argument add' -l branch -d 'Track branch' -x
complete -c git -n '__fish_git_using_command submodule; and __fish_seen_argument update' -l init -d 'Initialize submodules'
complete -c git -n '__fish_git_using_command submodule; and __fish_seen_argument update' -l recursive -d 'Recursive update'

# =============================================================================
# Common git subcommands
# =============================================================================
complete -c git -n 'test (count (commandline -opc)) -eq 1' -a 'add bisect blame branch checkout cherry cherry-pick clone commit diff fetch init log merge merge-base pull push rebase reflog reset restore revert rm show stash status submodule switch tag worktree' -d 'Command'