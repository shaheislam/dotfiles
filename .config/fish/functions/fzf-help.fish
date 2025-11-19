# fzf-help - Comprehensive FZF functionality reference
function fzf-help --description "Show comprehensive fzf search syntax, keybindings, and custom functions"
    set -l help_text "
╭──────────────────────────────────────────────────────────────────────────╮
│                   FZF Comprehensive Reference Guide                      │
╰──────────────────────────────────────────────────────────────────────────╯

QUICK REFERENCE - Most Used Commands:
  fe                File/directory explorer with preview
  fzf-help          Show this comprehensive help guide

  Git:       gco (checkout)  gstash (stashes)  CTRL-G CTRL-B (branches)
  Docker:    CTRL-D CTRL-C (containers)  CTRL-D CTRL-I (images)  CTRL-D CTRL-V (volumes)
  K8s:       kctx (context)  kns (namespace)  kpod (pods)
  Process:   killp  psf  mem  cpu  procmon
  Ports:     port  ports  portmon

═══════════════════════════════════════════════════════════════════════════
 CORE FZF SEARCH SYNTAX
═══════════════════════════════════════════════════════════════════════════

SEARCH OPERATORS:
  ^pattern          Match beginning of line (^README matches README.md)
  pattern\$          Match end of line (.md\$ matches all markdown files)
  pattern1 | pattern2    OR operator ('.yml\$ | .yaml\$')
  pattern1 pattern2      AND operator ('config .fish')
  !pattern          NOT operator (!test excludes files with 'test')

COMMON COMBINATIONS:
  '.ts\$ | .tsx\$'       All TypeScript files
  '.yml\$ !secrets'     YAML files excluding secrets
  '^src/ .ts\$'         TypeScript files in src directory
  '!node_modules .js\$' JS files excluding node_modules

GLOBAL KEYBINDINGS:
  ctrl-/            Toggle preview panel
  ctrl-u/d          Preview page up/down
  ctrl-y/e          Preview scroll line up/down
  ctrl-a            Select all visible items
  ctrl-x            Deselect all items
  tab/shift-tab     Select/deselect and navigate
  enter             Confirm selection
  esc               Cancel/exit

═══════════════════════════════════════════════════════════════════════════
 FILE OPERATIONS
═══════════════════════════════════════════════════════════════════════════

fe                File/directory explorer with toggle
  • ctrl-t        Toggle between files and directories
  • ctrl-o        Open file/directory
  • ctrl-a        Select all
  • tab           Multi-select
  • enter         Edit files or cd to directory

FISH PLUGIN KEYBINDINGS (from fzf.fish):
  alt-c (esc+c)   Search directories
  alt-f (esc+f)   Search files
  ctrl-r          Search history (via Atuin)
  alt-l (esc+l)   Search git log
  alt-s (esc+s)   Search git status
  alt-p (esc+p)   Search processes
  ctrl-v          Search variables

═══════════════════════════════════════════════════════════════════════════
 GIT OPERATIONS
═══════════════════════════════════════════════════════════════════════════

SELECTION MODE (CTRL-G) - From junegunn/fzf-git.sh:
  ctrl-g ctrl-f   Files - Select git files
  ctrl-g ctrl-b   Branches - Select branch
  ctrl-g ctrl-h   Commit hashes - Select commit
  ctrl-g ctrl-t   Tags - Select tag
  ctrl-g ctrl-r   Remotes - Select remote
  ctrl-g ctrl-s   Stashes - Select stash
  ctrl-g ctrl-l   Reflogs - Select reflog entry
  ctrl-g ctrl-w   Worktrees - Select worktree
  ctrl-g ctrl-e   Each ref - Select any git ref

ACTION MODE (ALT-G) - Custom git actions:
  alt-g f         File actions (add/patch/discard/commit/amend/edit)
  alt-g c         Commit actions (checkout/reset/rebase/cherry-pick)
  alt-g b         Branch actions (checkout/merge/rebase/diff/log)
  alt-g ?         Show detailed git actions help

  Within fzf git interfaces:
    ctrl-o        Open in browser/tool
    alt-e         Edit file
    ctrl-d        View diff
    alt-p         Patch add (in file actions)
    alt-c         Checkout/commit operations
    alt-m         Merge (in branch actions)
    alt-r         Rebase/reset operations

CUSTOM GIT FUNCTIONS:
  gco             Git checkout branch/tag with fzf selection
  gstash          Manage git stashes with fzf
    • enter       Apply stash
    • ctrl-p      Pop stash
    • ctrl-d      Drop stash

  gx              Interactively delete git branches (multi-select)
  gwtl            List/switch git worktrees with fzf
  gwtr            Remove git worktree with fzf selection

GITHUB GIST FUNCTIONS:
  gisls           List and manage GitHub gists with fzf
  gisdel          Delete GitHub gists with fzf selection

═══════════════════════════════════════════════════════════════════════════
 DOCKER OPERATIONS
═══════════════════════════════════════════════════════════════════════════

SELECTION MODE (CTRL-D) - Docker FZF Integration:
  ctrl-d ctrl-c   Containers (running) - Select running container
  ctrl-d ctrl-a   All Containers - Select any container (including stopped)
  ctrl-d ctrl-i   Images - Select Docker image
  ctrl-d ctrl-v   Volumes - Select Docker volume
  ctrl-d ctrl-n   Networks - Select Docker network
  ctrl-d ctrl-s   Compose Services - Select docker-compose service
  ctrl-d ?        Help - Show Docker FZF bindings

  Within fzf docker interfaces:
    ctrl-e        Execute shell in container
    ctrl-l        View logs (follow mode)
    ctrl-s        Stop/Start (context-dependent)
    ctrl-r        Restart/Run (context-dependent)
    ctrl-x        Remove (containers/images/volumes/networks)
    ctrl-i        Inspect (detailed info)
    alt-a         Show all (toggle filter)

TAB COMPLETION - Context-aware Docker command completion:
  docker ps <TAB>           List containers
  docker exec <TAB>         Select running container
  docker logs <TAB>         Select any container
  docker rm <TAB>           Select stopped containers
  docker images <TAB>       List images
  docker rmi <TAB>          Select image to remove
  docker volume ls <TAB>    List volumes
  docker network ls <TAB>   List networks
  docker compose up <TAB>   Select compose service

LEGACY FUNCTIONS (deprecated, use CTRL-D instead):
  dps             Select Docker container for operations
  dcon            Select Docker container (simple selector)
  dimg            Select Docker image for operations

═══════════════════════════════════════════════════════════════════════════
 KUBERNETES OPERATIONS
═══════════════════════════════════════════════════════════════════════════

kctx            Switch Kubernetes context with fzf
  • Preview shows context configuration

kns             Switch Kubernetes namespace with fzf
  • Preview shows pods in namespace

kpod            Select Kubernetes pod for operations
  • enter       Describe pod
  • ctrl-l      View pod logs
  • ctrl-e      Exec into pod (/bin/sh)
  • ctrl-d      Delete pod
  • Preview shows pod details

kubectl get     Enhanced with fzf selection (via wrapper)
  • ctrl-y      View full YAML in pager
  • ctrl-e      View kubectl describe in pager
  • ctrl-d/u    Scroll preview page down/up
  • ctrl-f/b    Scroll preview line down/up

═══════════════════════════════════════════════════════════════════════════
 PROCESS MONITORING
═══════════════════════════════════════════════════════════════════════════

killp           Kill process with fzf selection (multi-select)
  • tab         Select multiple processes
  • ctrl-a      Select all
  • enter       Kill selected processes (PID extraction)

psf             Interactive process search with actions
  • enter       View detailed process info
  • ctrl-k      Kill selected process
  • ctrl-r      Refresh process list
  • Preview shows process tree

psg <term>      Search processes matching term with fzf
  • enter       View process details
  • ctrl-k      Kill process
  • Preview shows process tree

mem             Show memory usage by process (sorted)
  • Preview shows PID, memory, CPU, command

cpu             Show CPU usage by process (sorted)
  • Preview shows PID, CPU, memory, command

procmon         Interactive real-time process monitor
  • enter       View process details
  • ctrl-k      Kill process
  • ctrl-r      Refresh list
  • esc         Exit monitor
  • Preview shows process tree

═══════════════════════════════════════════════════════════════════════════
 PORT & NETWORK MONITORING
═══════════════════════════════════════════════════════════════════════════

port [number]   Show what's listening on a port
  • Without arg: fzf selection from all listening ports
  • With arg: Direct port inspection

ports           Show all listening ports with fzf filtering
  • Preview shows process, PID, user, port details

portmon         Interactive port monitor
  • enter       View connection details
  • ctrl-k      Kill process using port
  • ctrl-r      Refresh port list
  • esc         Exit monitor

netstat-tuln    Show all listening ports (netstat style)
  • Preview shows process, PID, port

dnslookup       Perform DNS lookup with record type selection
  • fzf selection of DNS record types (A, AAAA, MX, etc.)

═══════════════════════════════════════════════════════════════════════════
 AWS & CLOUD OPERATIONS
═══════════════════════════════════════════════════════════════════════════

aws-sso         Authenticate with AWS SSO
  • fzf profile selection
  • Automatic credential refresh

awsp            Switch AWS profile with fzf
  • Reads from ~/.aws/config
  • Preview shows profile configuration

s3-dates        List and explore S3 log dates with fzf
  • Date-based S3 log exploration

s3-browse       Interactive S3 bucket browser with fzf
  • Navigate S3 buckets and prefixes
  • Preview file contents

logs            Quick AWS log search with fzf bucket selection
  • CloudWatch Logs integration
  • Bucket and log group selection

═══════════════════════════════════════════════════════════════════════════
 DEVOPS TOOLS
═══════════════════════════════════════════════════════════════════════════

tfw             Switch Terraform workspace with fzf
  • Shows all available workspaces
  • Preview shows workspace details

helmr           Select Helm release with fzf
  • List all Helm releases
  • Operations on selected release

secsan          Run security scans with fzf selection
  • Select scan type interactively
  • Integration with security tools

portscan        Scan ports with nmap and fzf
  • Interactive port range selection
  • fzf-based result filtering

logsf           View logs with fzf and lnav
  • Log file selection via fzf
  • Opens in lnav for analysis

═══════════════════════════════════════════════════════════════════════════
 ENVIRONMENT VARIABLES
═══════════════════════════════════════════════════════════════════════════

FZF CONFIGURATION:
  FZF_DEFAULT_COMMAND    Command to generate file list
  FZF_DEFAULT_OPTS       Default fzf options (theme, layout)
  FZF_CTRL_T_OPTS        Options for file search (ctrl-t)
  FZF_ALT_C_OPTS         Options for directory search (alt-c)
  KUBECTL_FZF_OPTS       Custom kubectl fzf options

═══════════════════════════════════════════════════════════════════════════
 ZSH-SPECIFIC FEATURES (if using Zsh)
═══════════════════════════════════════════════════════════════════════════

**                     Trigger fzf completion (e.g., cd **<TAB>)

Command-specific previews via _fzf_comprun():
  cd **<TAB>           Directory tree preview
  export **<TAB>       Variable value preview
  ssh **<TAB>          DNS lookup preview
  kubectl **<TAB>      YAML resource preview
  docker **<TAB>       Container inspect preview
  git **<TAB>          Git object/file preview
  <any> **<TAB>        File content with bat

Custom completion functions:
  git <TAB>            Fuzzy search all git commands
  kubectl <TAB>        Fuzzy search k8s API resources
  docker <TAB>         Fuzzy search running containers

═══════════════════════════════════════════════════════════════════════════
 TIPS & TRICKS
═══════════════════════════════════════════════════════════════════════════

• Use quotes for complex searches: '.yml\$ | .yaml\$ !secrets'
• Multi-select with tab, then enter to confirm
• Preview is searchable - use ctrl-f to search within preview
• Combine operators: '^src/ !test .ts\$' for source TS files
• Case-insensitive by default (smart-case enabled)
• ctrl-/ works in all fzf interfaces to toggle preview
• Most functions support multi-select with tab
• Use --help flag on custom functions for detailed usage

═══════════════════════════════════════════════════════════════════════════
 RELATED DOCUMENTATION
═══════════════════════════════════════════════════════════════════════════

Git Actions:      alt-g ?  (detailed git workflow help)
Docker Actions:   ctrl-d ?  (detailed docker workflow help)
FZF Project:      https://github.com/junegunn/fzf
FZF Git:          https://github.com/junegunn/fzf-git.sh
FZF Docker:       Custom integration (fzf-docker.sh in functions/)
FZF Fish Plugin:  https://github.com/PatrickF1/fzf.fish

═══════════════════════════════════════════════════════════════════════════
"

    # Display help text with bat if available, otherwise use less
    if command -v bat >/dev/null
        echo "$help_text" | bat --language=help --style=grid --paging=always
    else
        echo "$help_text" | less -R
    end
end
