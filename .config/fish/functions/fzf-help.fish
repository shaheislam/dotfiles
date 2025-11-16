# fzf-help - Display fzf search syntax and keybindings
function fzf-help --description "Show fzf search syntax, keybindings, and usage examples"
    set -l help_text "
╭──────────────────────────────────────────────────────────────────╮
│                    FZF Search Syntax & Tips                      │
╰──────────────────────────────────────────────────────────────────╯

SEARCH SYNTAX:
  ^pattern          Match beginning of line
                    Example: ^README (matches README.md at start)

  pattern\$          Match end of line
                    Example: .md\$ (matches all markdown files)

  pattern1 | pattern2    OR operator
                    Example: '.yml\$ | .yaml\$' (matches both extensions)

  pattern1 pattern2      AND operator (space)
                    Example: 'config .fish' (both terms must match)

  !pattern          NOT operator (exclude)
                    Example: '!test' (excludes files with 'test')

COMMON COMBINATIONS:
  '.ts\$ | .tsx\$'       All TypeScript files
  '.yml\$ !secrets'     YAML files excluding those with 'secrets'
  '^src/ .ts\$'         TypeScript files in src directory
  '!node_modules .js\$' JS files excluding node_modules
  '^.config/ .fish\$'   Fish config files in .config directory

GLOBAL KEYBINDINGS:
  ctrl-/            Toggle preview panel
  ctrl-u            Preview page up
  ctrl-d            Preview page down
  ctrl-y            Preview scroll up (line)
  ctrl-e            Preview scroll down (line)
  ctrl-a            Select all visible items
  ctrl-x            Deselect all items
  tab               Select/deselect current item
  shift-tab         Select/deselect and move up
  enter             Confirm selection
  esc               Cancel/exit

CUSTOM FUNCTIONS:
  fe                File explorer (toggle files/dirs with ctrl-t)
  fzf-help          Show this help (you're viewing it now!)

KUBECTL KEYBINDINGS (when using 'kubectl get'):
  ctrl-y            View full YAML in pager
  ctrl-e            View kubectl describe in pager
  ctrl-d/u          Scroll preview page down/up
  ctrl-f/b          Scroll preview line down/up

PROCESS VIEWER KEYBINDINGS (kill-process, ports, etc.):
  ctrl-k            Kill selected process
  ctrl-r            Reload process list

DOCKER KEYBINDINGS:
  ctrl-e            Execute shell in container
  ctrl-s            Stop container
  ctrl-r            Restart container

GIT KEYBINDINGS:
  Selection Mode (CTRL-G) - From junegunn/fzf-git.sh:
    ctrl-g ctrl-f   Files
    ctrl-g ctrl-b   Branches
    ctrl-g ctrl-h   Commit hashes
    ctrl-g ctrl-t   Tags
    ctrl-g ctrl-r   Remotes
    ctrl-g ctrl-s   Stashes
    ctrl-g ctrl-l   Reflogs
    ctrl-g ctrl-w   Worktrees
    ctrl-g ctrl-e   Each ref

  Action Mode (ALT-G) - Custom git actions:
    alt-g f         File actions (add/reset + operations)
    alt-g c         Commit actions (checkout/reset/rebase/cherry-pick)
    alt-g b         Branch actions (checkout/merge/rebase)
    alt-g ?         Show git actions help

  Within fzf interface:
    ctrl-o          Open in browser/tool
    alt-e           Edit file
    ctrl-d          View diff

TIPS:
  • Use quotes for complex searches: '.yml\$ | .yaml\$ !secrets'
  • Multi-select with tab, then enter to confirm selection
  • Preview is searchable - use ctrl-f to search within preview
  • Combine operators: '^src/ !test .ts\$' for source TS files
  • Case-insensitive by default (search is smart-case)

ENVIRONMENT VARIABLES:
  FZF_DEFAULT_COMMAND    Command to generate file list
  FZF_DEFAULT_OPTS       Default fzf options
  FZF_CTRL_T_OPTS        Options for file search (ctrl-t)
  FZF_ALT_C_OPTS         Options for directory search (alt-c)
  KUBECTL_FZF_OPTS       Custom kubectl fzf options

ZSH-SPECIFIC FEATURES (if using Zsh):
  **                     Trigger fzf completion (e.g., cd **<TAB>)
                         Uses custom _fzf_compgen_path() and _fzf_compgen_dir()

  Command-specific previews via _fzf_comprun():
    cd **<TAB>           Shows directory tree preview
    export **<TAB>       Shows variable value preview
    ssh **<TAB>          Shows DNS lookup preview
    kubectl **<TAB>      Shows YAML resource preview
    docker **<TAB>       Shows container inspect preview
    git **<TAB>          Shows git object/file preview
    <any> **<TAB>        Shows file content with bat

  Custom completion functions:
    git <TAB>            Fuzzy search all git commands
    kubectl <TAB>        Fuzzy search k8s API resources
    docker <TAB>         Fuzzy search running containers

FISH-SPECIFIC FEATURES:
  alt-tab              Trigger carapace fzf completion
  Keybindings from fzf.fish plugin:
    alt-c (esc+c)      Search directories
    alt-f (esc+f)      Search files
    ctrl-r             Search history (via Atuin)
    alt-l (esc+l)      Search git log
    alt-s (esc+s)      Search git status
    alt-p (esc+p)      Search processes
    ctrl-v             Search variables

For more information: https://github.com/junegunn/fzf
"

    # Display help text with bat if available, otherwise use less
    if command -v bat >/dev/null
        echo "$help_text" | bat --language=help --style=grid --paging=always
    else
        echo "$help_text" | less -R
    end
end
