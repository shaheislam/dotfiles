# Git FZF Action Keybindings
# ALT-G prefix for git action workflows
# Complements existing CTRL-G selection workflows from fzf-git.sh

# Only load in interactive mode
if status is-interactive
    # ALT-G F - Git file actions (add/reset with operations)
    bind -M default \egf '_git_fzf_file_actions'
    bind -M insert \egf '_git_fzf_file_actions'
    bind -M default \eg\cf '_git_fzf_file_actions'
    bind -M insert \eg\cf '_git_fzf_file_actions'

    # ALT-G C - Git commit actions (checkout, reset, rebase, cherry-pick)
    bind -M default \egc '_git_fzf_commit_actions'
    bind -M insert \egc '_git_fzf_commit_actions'
    bind -M default \eg\cc '_git_fzf_commit_actions'
    bind -M insert \eg\cc '_git_fzf_commit_actions'

    # ALT-G B - Git branch actions (checkout, merge, rebase)
    bind -M default \egb '_git_fzf_branch_actions'
    bind -M insert \egb '_git_fzf_branch_actions'
    bind -M default \eg\cb '_git_fzf_branch_actions'
    bind -M insert \eg\cb '_git_fzf_branch_actions'

    # ALT-G U - Git clean/untracked file actions
    bind -M default \egu '_git_fzf_clean_actions'
    bind -M insert \egu '_git_fzf_clean_actions'

    # ALT-G I - Gitignore generator
    bind -M default \egi '_git_fzf_gitignore'
    bind -M insert \egi '_git_fzf_gitignore'

    # ALT-G A - Gitattributes generator
    bind -M default \ega '_git_fzf_gitattributes'
    bind -M insert \ega '_git_fzf_gitattributes'

    # ALT-G S - Git stash push (select files to stash)
    bind -M default \egs '_git_fzf_stash_push'
    bind -M insert \egs '_git_fzf_stash_push'

    # ALT-G L - Git blame viewer
    bind -M default \egl '_git_fzf_blame'
    bind -M insert \egl '_git_fzf_blame'

    # ALT-G ? - Show help for git fzf actions
    bind -M default \eg\? '_git_fzf_actions_help'
    bind -M insert \eg\? '_git_fzf_actions_help'
end

# Help function for git fzf actions
function _git_fzf_actions_help
    echo "
╭────────────────────────────────────────────────────────────────────────╮
│                    Git FZF Action Keybindings                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  SELECTION MODE (CTRL-G) - From junegunn/fzf-git.sh:                  │
│    CTRL-G CTRL-F   Files                                               │
│    CTRL-G CTRL-B   Branches                                            │
│    CTRL-G CTRL-H   Commit Hashes                                       │
│    CTRL-G CTRL-T   Tags                                                │
│    CTRL-G CTRL-R   Remotes                                             │
│    CTRL-G CTRL-S   Stashes                                             │
│    CTRL-G CTRL-L   Reflogs                                             │
│    CTRL-G CTRL-W   Worktrees                                           │
│    CTRL-G CTRL-E   Each ref                                            │
│                                                                         │
│  ACTION MODE (ALT-G) - Custom action workflows:                        │
│    ALT-G F         File actions (add/reset + operations)               │
│    ALT-G C         Commit actions (checkout/reset/rebase/fixup/squash) │
│    ALT-G B         Branch actions (checkout/merge/rebase/delete)       │
│    ALT-G S         Stash push (select specific files to stash)         │
│    ALT-G L         Blame viewer (interactive git blame)                │
│    ALT-G U         Untracked/clean actions (delete untracked files)    │
│    ALT-G I         Gitignore generator (fetch from gitignore.io)       │
│    ALT-G A         Gitattributes generator (from github templates)     │
│    ALT-G ?         Show this help                                      │
│                                                                         │
├────────────────────────────────────────────────────────────────────────┤
│                  Within FZF Interface Keybindings                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  File Actions (ALT-G F):                                               │
│    CTRL-S          Toggle Add/Reset mode                               │
│    ALT-P           Add patch (interactive staging)                     │
│    ALT-D           Checkout/discard changes                            │
│    ALT-C           Commit staged files                                 │
│    ALT-A           Amend last commit                                   │
│    ALT-E           Open in editor                                      │
│    CTRL-/          Toggle preview                                      │
│                                                                         │
│  Commit Actions (ALT-G C):                                             │
│    ENTER           Show full commit                                    │
│    ALT-C           Checkout commit (detached HEAD)                     │
│    ALT-R           Hard reset to commit                                │
│    ALT-I           Interactive rebase                                  │
│    ALT-P           Cherry-pick commit                                  │
│    ALT-F           Fixup + autosquash (auto-rebase)                    │
│    ALT-S           Squash + autosquash (auto-rebase)                   │
│    ALT-W           Reword + autosquash (auto-rebase)                   │
│    ALT-V           Revert commit (create undo commit)                  │
│    CTRL-/          Toggle preview                                      │
│    CTRL-Y/E        Scroll preview up/down                              │
│    CTRL-U/D        Half-page preview scroll                            │
│                                                                         │
│  Branch Actions (ALT-G B):                                             │
│    ALT-C           Checkout branch                                     │
│    ALT-M           Merge branch into current                           │
│    ALT-R           Rebase current onto selected                        │
│    ALT-X           Delete branch                                       │
│    ALT-D           Preview diff with current branch                    │
│    ALT-L           Preview branch commits                              │
│    CTRL-/          Toggle preview                                      │
│                                                                         │
│  Untracked/Clean Actions (ALT-G U):                                    │
│    ENTER           Delete selected untracked files                     │
│    ALT-D           Dry-run (show what would be deleted)                │
│    ALT-A           Delete all untracked files                          │
│    CTRL-/          Toggle preview                                      │
│                                                                         │
│  Stash Push Actions (ALT-G S):                                         │
│    TAB             Multi-select files to stash                         │
│    ENTER           Stash selected files                                │
│    ALT-A           Stash all changes                                   │
│    ALT-M           Stash with custom message                           │
│    CTRL-/          Toggle preview                                      │
│                                                                         │
│  Blame Viewer (ALT-G L):                                               │
│    ENTER           Show commit details                                 │
│    ALT-E           Open commit in nvim                                 │
│    ALT-C           Checkout commit                                     │
│    ALT-P           Blame parent commit (time travel)                   │
│    CTRL-/          Toggle preview                                      │
│    CTRL-Y/E        Scroll preview up/down                              │
│    CTRL-U/D        Half-page preview scroll                            │
│                                                                         │
│  Gitignore Generator (ALT-G I):                                        │
│    TAB             Multi-select templates                              │
│    ENTER           Generate .gitignore with selected templates         │
│                                                                         │
│  Gitattributes Generator (ALT-G A):                                    │
│    TAB             Multi-select templates                              │
│    ENTER           Generate .gitattributes with selected templates     │
│                                                                         │
├────────────────────────────────────────────────────────────────────────┤
│                  FZF Picker Toggle (inside any picker)                 │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Switch picker type while inside FZF (from fzf-git.sh):                │
│    CTRL-G CTRL-B   Switch to branches                                  │
│    CTRL-G CTRL-F   Switch to files                                     │
│    CTRL-G CTRL-H   Switch to hashes (commits)                          │
│    CTRL-G CTRL-T   Switch to tags                                      │
│    CTRL-G CTRL-R   Switch to remotes                                   │
│    CTRL-G CTRL-S   Switch to stashes                                   │
│                                                                         │
╰────────────────────────────────────────────────────────────────────────╯
" | less -R
end
