# Fish Shell Configuration
# Integrated configuration combining dotfiles setup with extended functionality

# Helper functions for completions moved to functions directory

# Completions for AWS functions with descriptions
complete -c ct-view -e
complete -c ct-view -f -a "(__fish_complete_aws_s3_buckets)" -d "Search and analyze AWS CloudTrail logs in S3 buckets"

complete -c gd-view -e
complete -c gd-view -f -a "(__fish_complete_aws_s3_buckets)" -d "Search and analyze AWS GuardDuty security findings in S3"

complete -c s3-logs -e
complete -c s3-logs -f -a "(__fish_complete_aws_s3_buckets)" -d "Search and format JSON logs from S3 buckets using s3grep"

complete -c s3-dates -e
complete -c s3-dates -f -a "(__fish_complete_aws_s3_buckets)" -d "List available dates in S3 log buckets with filtering"

complete -c s3-browse -e
complete -c s3-browse -f -a "(__fish_complete_aws_s3_buckets)" -d "Interactive browser for exploring S3 log buckets"

complete -c logs -e
complete -c logs -f -a "AssumeRole CreateBucket RunInstances UnauthorizedAccess root" -d "Quick AWS log search with auto-detection of common buckets"

complete -c ssmc -e
complete -c ssmc -f -a "(__fish_complete_aws_profiles)" -d "Connect to EC2 instances via AWS SSM with interactive selection"

complete -c aws-sso -e
complete -c aws-sso -f -a "(__fish_complete_aws_profiles)" -d "Authenticate with AWS SSO and export credentials to environment"

complete -c dssmc -e
complete -c dssmc -f -a "(__fish_complete_aws_profiles)" -d "Connect to EC2 via SSM tunnel for distant.nvim"

# Only run in interactive sessions
if status is-interactive
    # Set key bindings for better autocomplete
    set -g fish_key_bindings fish_vi_key_bindings
    set -g fish_escape_delay_ms 10

    # Fix arrow key bindings for vi mode
    # Clear any corrupted bindings first
    bind -M insert -e \e\[B 2>/dev/null
    bind -M default -e \e\[B 2>/dev/null

    # Set correct bindings
    bind -M insert \e\[A up-or-search
    bind -M insert \e\[B down-or-search
    bind -M insert \e\[C forward-char
    bind -M insert \e\[D backward-char

    bind -M default \e\[A up-line
    bind -M default \e\[B down-line
    bind -M default \e\[C forward-char
    bind -M default \e\[D backward-char

    # Environment Variables
    set -x BAT_THEME "Catppuccin Mocha"
    set -x BAT_PAGING never # Prevents FZF preview file descriptor errors
    # Pager defaults (avoid tools reading a bad $PAGER value)
    set -x PAGER less
    set -x MANPAGER "less -R"
    set -x STARSHIP_CONFIG $HOME/.config/starship.toml
    # set -x TERM screen-256color  # Disabled to prevent VS Code integration issues

    # Claude Code environment
    set -gx FORCE_AUTOUPDATE_PLUGINS 1 # Auto-update plugins on session start
    set -gx CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD 1 # Load CLAUDE.md from --add-dir paths
    set -gx CLAUDE_CODE_EFFORT_LEVEL medium # env var: low|medium|high|max|auto (max=Opus 4.6 only, session-scoped)
    set -gx CLAUDE_CODE_NO_FLICKER 0 # Explicitly disable fullscreen renderer by default to avoid redraw issues

    # PinchTab - Multi-instance Chrome orchestrator for AI agents
    set -gx PINCHTAB_PORT 9867
    set -gx PINCHTAB_CONFIG "$HOME/.config/pinchtab/config.json"
    # OpenTelemetry observability (harness engineering)
    set -gx CLAUDE_CODE_ENABLE_TELEMETRY 1
    set -gx OTEL_EXPORTER_OTLP_ENDPOINT "http://localhost:4318"

    # ==================== Platform-Specific Configuration ====================

    # WSL-specific configuration
    if test -n "$WSL_DISTRO_NAME"
        # Windows interop - use wslview for opening URLs/files
        set -x BROWSER wslview

        # Docker Desktop integration (if available)
        if test -S "/mnt/wsl/docker-desktop/docker.sock"
            set -x DOCKER_HOST "unix:///mnt/wsl/docker-desktop/docker.sock"
        else if test -S "$HOME/.docker/run/docker.sock"
            set -x DOCKER_HOST "unix://$HOME/.docker/run/docker.sock"
        end

        # Windows home directory for easy access
        set -x WIN_HOME (wslpath (cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n') 2>/dev/null)

        # Add PioSolver to PATH if installed
        if test -d "/mnt/c/Program Files/PioSOLVER"
            set -x PATH $PATH "/mnt/c/Program Files/PioSOLVER"
        end

        # Clipboard integration aliases
        alias clip "clip.exe"
        alias paste "powershell.exe Get-Clipboard"

        # Open Windows Explorer from WSL
        alias explorer "explorer.exe"

        # Windows app shortcuts
        alias obsidian "'/mnt/c/Program Files/Obsidian/Obsidian.exe' &"
        alias piosolver "PioSOLVER2-edge.exe"

    else
        # macOS/Linux: Colima Docker configuration
        set -x DOCKER_HOST "unix://$HOME/.colima/default/docker.sock"
    end

    # Load centralized PATH configuration
    source $HOME/.config/fish/paths.fish

    # API Keys for Claude Code Router
    # Load from ~/dotfiles/.env if it exists (after stow symlink)
    # OPTIMIZED: Single sed pass instead of character-by-character parsing
    if test -f ~/.env
        sed -E '/^[[:space:]]*#/d; /^[[:space:]]*$/d; s/^export[[:space:]]+//; s/^([^=]+)=["'"'"']?([^"'"'"']*)["'"'"']?$/set -gx \1 "\2"/' ~/.env | source
    end

    # ==================== Homebrew Auto-Update ====================
    # Update Homebrew index daily when any brew command is run (default: 300s/5min)
    set -gx HOMEBREW_AUTO_UPDATE_SECS 86400

    # ==================== Tool Initialization (Cached for Performance) ====================
    # Using __cache_tool_init for ~50-100ms startup improvement
    # Cache invalidates automatically when tool version changes
    # PERF: Use `test -x /opt/homebrew/bin/<tool>` instead of `type -q <tool>`.
    # type -q scans every PATH entry (~120 dirs including Nix store) taking ~35ms per call.
    # test -x is a single stat() syscall (~1ms). With ~14 tools this saves ~450ms total.
    set -l _brew /opt/homebrew/bin

    if test -x $_brew/starship
        # PERF: Use --print-full-init to cache the actual init script, not a source shim.
        # `starship init fish` outputs `source (starship init fish --print-full-init | psub)`
        # which re-runs the subprocess on every startup, defeating the cache (~48ms).
        __cache_tool_init starship "starship init fish --print-full-init"
        # Enable transient prompt for cleaner terminal history
        enable_transience
    end

    if test -x $_brew/zoxide
        __cache_tool_init zoxide "zoxide init fish"
    end

    if test -x $_brew/glab
        __cache_tool_init glab "glab completion --shell=fish"
        # Populate GITLAB_TOKEN from glab's stored auth so opencode can use GitLab Duo models
        set -gx GITLAB_TOKEN (glab auth token --hostname gitlab.com 2>&1)
    end

    if test -x $_brew/direnv
        # Suppress direnv log messages (loading/unloading/using) for cleaner cd output
        set -gx DIRENV_LOG_FORMAT ""
        # PERF: eval_after_arrow defers direnv re-evaluation until the next command
        # after cd, instead of running `direnv export fish` on every prompt (~10-30ms).
        # Must be set BEFORE sourcing direnv hook.
        set -g direnv_fish_mode eval_after_arrow
        __cache_tool_init direnv "direnv hook fish"

        # PERF: Override direnv's fish_prompt handler. The default runs
        # `direnv export fish` on prompt render, which makes new tmux panes in
        # Nix-backed worktrees feel stuck. Defer the initial export until
        # fish_preexec so the prompt appears immediately and the first real
        # command pays the Nix/direnv cost instead.
        #
        # BUG FIX: The upstream eval_after_arrow pattern (direnv 2.34+) defines
        # the PWD hook inside fish_prompt and erases it in fish_preexec. But
        # fish_preexec fires BEFORE cd runs, so the hook is gone when PWD
        # actually changes. Fix: define the PWD hook ONCE (persistently) instead
        # of recreating it every prompt. The hook stays alive across the
        # preexec/cd boundary.
        #
        # NOTE: These overrides are inline in config.fish (not in functions/)
        # because --on-event and --on-variable handlers must be sourced to
        # register — Fish autoload won't register event handlers until explicit
        # call. They must also be defined AFTER __cache_tool_init sources the
        # cached upstream init so our definitions replace the upstream ones.
        #
        # Walk up from PWD to find the nearest .envrc (pure Fish, no subprocess).
        # Used by the direnv scope-tracking hooks below and by `denv`.
        function _find_nearest_envrc --description "Find nearest .envrc by walking up from PWD"
            set -l dir "$PWD"
            while test -n "$dir" -a "$dir" != /
                if test -f "$dir/.envrc"
                    echo "$dir/.envrc"
                    return 0
                end
                set dir (string replace -r '/[^/]+$' '' -- "$dir")
            end
            return 1
        end

        # Overrides __direnv_export_eval from `direnv hook fish`.
        # Verified: direnv 2.37.1 outputs this pattern (2026-02-15).
        function __direnv_export_eval --on-event fish_prompt
            if not set -q __direnv_initialized
                set -g __direnv_initialized 1
                set -g __direnv_last_envrc ""
                set -g __direnv_export_again 0
            end
        end

        # PERF: Persistent PWD hook for direnv. Defined once (not per-prompt).
        # Sets a flag so the preexec handler knows to check direnv scope.
        # This hook survives across the fish_preexec → cd → fish_prompt cycle.
        function __direnv_cd_hook --on-variable PWD
            set -g __direnv_export_again 0
        end

        # PERF: Override direnv's preexec handler to skip re-evaluation when
        # we're still in the same .envrc scope. Direnv takes ~660ms per call
        # due to Nix flake evaluation. By finding the nearest .envrc ourselves
        # (pure Fish walk-up, no subprocess), we skip the expensive call for cd
        # within the same project tree. Only re-evaluates when crossing .envrc
        # boundaries (e.g., cd from one project to another).
        #
        # Overrides __direnv_export_eval_2 from `direnv hook fish` (direnv >=2.34).
        function __direnv_export_eval_2 --on-event fish_preexec
            if set -q __direnv_export_again
                set -e __direnv_export_again
                set -l found_envrc (_find_nearest_envrc; or echo "")
                # Skip expensive direnv if same .envrc scope as last evaluation
                if test "$found_envrc" = "$__direnv_last_envrc"
                    : # Same scope — no re-evaluation needed
                else
                    /opt/homebrew/bin/direnv export fish | source
                    # Update scope tracker using walk-up path (worktree-safe)
                    set -g __direnv_last_envrc "$found_envrc"
                end
            end
        end

        # Convenience: `denv` forces a full direnv re-evaluation and resets the
        # scope cache. Use after editing .envrc without cd, or when switching
        # between worktrees that share identical .envrc content.
        function denv --description 'Force direnv reload and reset scope cache'
            /opt/homebrew/bin/direnv export fish | source
            set -g __direnv_last_envrc (_find_nearest_envrc; or echo "")
            # Also reset mise scope cache so next preexec re-evaluates.
            # Use empty string — won't match any "dir:mtime" value.
            set -g __mise_last_config ""
        end
    end

    if test -x $_brew/atuin
        set -gx ATUIN_NOBIND true
        # Skip the cached init - we'll define our own protected handlers
        # The cached version panics on invalid UTF-8 in command args

        # PERF: Generate session UUID in Fish instead of spawning `atuin uuid` (~30ms).
        # Atuin just needs a unique session identifier — any UUID v4 works.
        set -gx ATUIN_SESSION (printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x' (random 0 65535) (random 0 65535) (random 0 65535) (math "0x4000 + "(random 0 4095)) (math "0x8000 + "(random 0 16383)) (random 0 65535) (random 0 65535) (random 0 65535))
        set --erase ATUIN_HISTORY_ID

        # Protected preexec handler with UTF-8 sanitization
        function _atuin_preexec --on-event fish_preexec
            if not test -n "$fish_private_mode"
                # PERF: Skip iconv for pure-ASCII commands (vast majority of inputs).
                # Only sanitize when non-ASCII bytes are detected.
                set -l cmd "$argv[1]"
                if string match -qr '[^\x00-\x7f]' -- "$cmd"
                    set cmd (printf '%s' "$cmd" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null)
                end
                if test -n "$cmd"
                    set -g ATUIN_HISTORY_ID (atuin history start -- "$cmd" 2>/dev/null)
                end
            end
        end

        # Protected postexec handler
        function _atuin_postexec --on-event fish_postexec
            set -l s $status
            if test -n "$ATUIN_HISTORY_ID"
                ATUIN_LOG=error atuin history end --exit $s -- $ATUIN_HISTORY_ID &>/dev/null &
                disown
            end
            set --erase ATUIN_HISTORY_ID
        end
    end

    # Source asdf (no caching needed - it's just a file source)
    if test -f "/opt/homebrew/opt/asdf/libexec/asdf.fish"
        source /opt/homebrew/opt/asdf/libexec/asdf.fish
    end

    # mise — shims-based PATH integration. Replaced ~100 lines of cached
    # activate-mode + custom prompt/preexec overrides because the cached script
    # still ran `mise hook-env -s fish | source` synchronously at startup
    # (~216ms, dominated total fish startup). Shims (~/.local/share/mise/shims)
    # symlink each tool to the mise binary, which on first invocation reads
    # the nearest mise.toml/.tool-versions and execs the project-pinned binary.
    # PATH lookup cost: ~0ms.
    #
    # Trade-off: `[env]` blocks in mise.toml won't auto-export. None of the
    # active worktrees use them (only [tools] in ~/neovim/mise.toml as of
    # 2026-04-26). Re-add a hook-env-on-cd handler if that changes.
    if test -d "$HOME/.local/share/mise/shims"
        if not contains "$HOME/.local/share/mise/shims" $PATH
            set -gx PATH "$HOME/.local/share/mise/shims" $PATH
        end
    end

    # Yazi file manager wrapper - q to stay, Q to cd to navigated directory
    function yazi
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        command yazi $argv --cwd-file="$tmp"
        if read -z cwd <"$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

    # ==================== FZF Configuration ====================
    #
    # FZF Search Syntax:
    #   ^pattern    - Match beginning of line (e.g., ^README matches README.md at start)
    #   pattern$    - Match end of line (e.g., .md$ matches all markdown files)
    #   'pattern1 | pattern2' - OR operator (e.g., '.yml$ | .yaml$' matches both)
    #   'pattern1 pattern2'   - AND operator (e.g., 'config .fish' matches both terms)
    #   !pattern    - NOT operator (e.g., '!test' excludes test files)
    #
    # Example combinations:
    #   '.ts$ | .tsx$'        - All TypeScript files
    #   '.yml$ !secrets'      - YAML files excluding those with 'secrets'
    #   '^src/ .ts$'          - TypeScript files in src directory
    #
    # Common Keybindings (see fzf-help for full list):
    #   ctrl-/      - Toggle preview
    #   ctrl-u/d    - Preview page up/down
    #   ctrl-y/e    - Preview line up/down
    #   ctrl-a      - Select all
    #   ctrl-x      - Deselect all
    #   tab         - Select/deselect item
    #   shift-tab   - Select/deselect and move up

    # FZF configuration - enhanced version combining both configs
    # Cached for ~69ms startup improvement
    if test -x $_brew/fzf
        # PERF: Skip `fzf --fish` version probe (~57ms subprocess). Homebrew fzf is always
        # 0.48+ which supports --fish. The fallback path is for ancient Linux distros.
        __cache_tool_init fzf "fzf --fish"
    end

    # REMOVED: ~/.fzf.fish source was redundant with __cache_tool_init fzf above.
    # `fzf --fish` already provides key bindings and completions.

    # Enhanced FZF configuration from extended config
    if test -x $_brew/rg
        set -gx FZF_DEFAULT_COMMAND 'rg --files'
        set -gx FZF_DEFAULT_OPTS '-m --height 50% --border'
    else
        # Fallback to fd-based configuration
        set -gx FZF_DEFAULT_COMMAND "fd --hidden --strip-cwd-prefix --exclude .git"
    end

    # Keep the same command but now with preview options from above
    set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    # Keep the same command but now with preview options from above
    set -gx FZF_ALT_C_COMMAND "fd --type=d --hidden --strip-cwd-prefix --exclude .git"

    # FZF theme colors - Catppuccin Mocha theme to match other tools
    set -l fg "#cdd6f4" # Text
    set -l bg "#1e1e2e" # Base
    set -l bg_highlight "#313244" # Surface0
    set -l purple "#b4befe" # Lavender
    set -l blue "#89b4fa" # Blue
    set -l cyan "#89dceb" # Sky
    set -l green "#a6e3a1" # Green
    set -l orange "#fab387" # Peach
    set -l red "#f38ba8" # Red
    set -l yellow "#f9e2af" # Yellow
    set -l magenta "#cba6f7" # Mauve

    # Enhanced FZF options matching WezTerm aesthetics (simulated transparency)
    # Using -1 for bg creates transparent background effect
    set -gx FZF_DEFAULT_OPTS "--color=fg:$fg,bg:-1,hl:$blue,fg+:$fg,bg+:$bg_highlight,hl+:$magenta,info:$yellow,prompt:$cyan,pointer:$blue,marker:$green,spinner:$cyan,header:$purple,border:$bg_highlight,preview-bg:-1,preview-fg:$fg \
        --height 60% \
        --layout=reverse \
        --border=rounded \
        --border-label=' Search ' \
        --border-label-pos=3 \
        --preview-window='right:70%:wrap:rounded,<120(right,50%,wrap,border-left)' \
        --padding=1 \
        --margin=1 \
        --info=inline \
        --multi \
        --prompt='> ' \
        --pointer='>' \
        --marker='*' \
        --color='header:italic' \
        --bind='tab:toggle+down,shift-tab:toggle+up' \
        --bind='ctrl-/:toggle-preview' \
        --bind='ctrl-u:preview-half-page-up' \
        --bind='ctrl-d:preview-half-page-down' \
        --bind='ctrl-y:preview-up' \
        --bind='ctrl-e:preview-down' \
        --bind='ctrl-a:select-all' \
        --bind='ctrl-x:deselect-all' \
        --bind='alt-enter:print-query' \
        --bind='ctrl-l:clear-screen' \
        --bind='alt-e:execute(nvim {} < /dev/tty > /dev/tty)+abort'"

    # File preview with bat using Catppuccin theme and minimal style
    set -gx FZF_CTRL_T_OPTS "--preview 'bat --color=always --style=numbers,changes --line-range=:500 {} 2>/dev/null || cat {}' \
        --border-label=' Files ' \
        --preview-label=' Preview ' \
        --preview-label-pos=3 \
        --header 'CTRL-/: toggle preview | TAB: multi-select | ALT-E: edit in nvim'"

    # History search with preview and copy-to-clipboard
    # Detect clipboard command (macOS pbcopy vs Linux xclip/xsel)
    set -l _clip_cmd true # no-op fallback
    if test -x /usr/bin/pbcopy
        set _clip_cmd pbcopy
    else if test -x /usr/bin/xclip
        set _clip_cmd "xclip -selection clipboard"
    else if test -x /usr/bin/xsel
        set _clip_cmd "xsel --clipboard --input"
    end
    set -gx FZF_CTRL_R_OPTS "--preview 'echo {}' \
        --preview-window='up:3:wrap' \
        --border-label=' History ' \
        --header 'CTRL-Y: copy command | ENTER: execute' \
        --bind 'ctrl-y:execute-silent(echo -n {2..} | $_clip_cmd)+abort'"

    # Directory preview with eza tree view and enhanced aesthetics
    set -gx FZF_ALT_C_OPTS "--preview 'eza --tree --icons --level=2 --color=always {}' \
        --border-label=' Directories ' \
        --preview-label=' Tree View ' \
        --preview-label-pos=3 \
        --header 'CTRL-/: toggle preview'"

    # Disable fish greeting
    set -g fish_greeting ""

    # thefuck — lazy stub. Defining `fuck` upfront via `thefuck --alias` cost
    # ~57ms on every shell start; <1% of shells ever invoke `fuck`. The stub
    # self-deletes on first use, sources the real alias, then re-runs.
    if test -x $_brew/thefuck
        function fuck
            functions -e fuck
            thefuck --alias | source
            fuck $argv
        end
    end

    # Carapace completions initialization (cached for ~230ms startup improvement)
    if test -x $_brew/carapace
        __cache_tool_init carapace "carapace _carapace fish"
        # Remove Carapace's kubectl completions (Fish 4.1+ blocks autoload after complete -e)
        # Then explicitly source Fish-native evanlucas/fish-kubectl-completions
        complete -e kubectl
        source ~/.config/fish/completions/kubectl.fish
    end

    # Auto-attach to tmux session 'main' or create it if it doesn't exist
    # Only do this in WezTerm or when not already in tmux
    # Uses tmux new -A (attach-or-create) without exec so that:
    #   - Manual detach (prefix+d) returns to Fish, which then exits cleanly
    #   - No nested shells (Fish exits immediately after tmux returns)
    if test -z "$TMUX" -a "$TERM_PROGRAM" = WezTerm
        tmux-main
        if test $status -eq 0
            exit
        end
    end

    # Codex IDE integrated terminal: same auto-attach behavior.
    # __CFBundleIdentifier is set by macOS when Codex.app spawns the shell.
    # NOTE: do NOT key on $CODEX_COMPANION_SESSION_ID — that var is set by the
    # codex-openai-codex Claude Code plugin (~/.claude/session-env/<id>/sessionstart-hook-*.sh)
    # and would fire in every Claude Code session.
    if test -z "$TMUX" -a "$__CFBundleIdentifier" = com.openai.codex
        tmux-main
        if test $status -eq 0
            exit
        end
    end

    # Enhanced aliases combining both configs
    alias python=python3
    alias mkdir="mkdir -p"

    # Enhanced eza aliases with better visual organization (if eza installed)
    if test -x $_brew/eza
        alias ls="eza --icons --group-directories-first"
        alias ll="eza -la --icons --group-directories-first --git"
        alias la="eza -a --icons --group-directories-first"
        alias l="eza -lah --icons --group-directories-first --git"
        alias tree="eza --tree --icons --level=2"
        alias lt="eza --tree --icons --level=3"
    else
        alias ll="ls -la"
        alias la="ls -a"
        alias l="ls -lah"
    end

    # Homebrew shortcuts
    alias bu="brew update" # Update Homebrew index
    alias bup="brew upgrade" # Upgrade all packages
    alias buc="brew cleanup" # Remove old versions
    alias bud="brew doctor" # Check for issues
    alias bui="brew install" # Install a package
    alias bus="brew search" # Search packages
    alias buo="brew outdated" # List outdated packages
    alias bubu="brew update && brew upgrade" # Update + upgrade in one

    alias k=kubectl
    alias vi=nvim
    alias vim=nvim
    alias tmp="tmpmail --generate" # Quick temp email generation
    alias tmpm="tmpmail" # Check temp mailbox
    alias altair="open -a 'Altair GraphQL Client'" # Open Altair GraphQL Client

    # Note: kubectl wrapper function defined in ~/.config/fish/functions/kubectl.fish
    # Provides automatic fzf integration for 'kubectl get' commands with YAML preview
    #
    # Kubectl FZF Keybindings (default):
    #   ctrl-d    - Scroll preview down (page)
    #   ctrl-u    - Scroll preview up (page)
    #   ctrl-f    - Scroll preview down (line)
    #   ctrl-b    - Scroll preview up (line)
    #   ctrl-y    - View full YAML in pager
    #   ctrl-e    - View kubectl describe in pager
    #   enter     - Select resource
    #
    # Customize keybindings by setting KUBECTL_FZF_OPTS:
    # set -gx KUBECTL_FZF_OPTS "--bind='ctrl-p:preview-up' --bind='ctrl-n:preview-down'"

    # Splash log colorizer integration
    # Automatically pipe common log-producing commands through splash
    # Moved to functions/: docker, journalctl, tail, cat, less, terraform, go, npm, yarn, pnpm, logcolor, logsearch
    if test -x $_brew/splash
        # Functions moved to separate files in functions/ for autoloading
    end

    # Helper functions for highlighted command output
    function gos --description "Run go command with highlighted search term"
        if test (count $argv) -lt 2
            echo "Usage: gos <search-term> <go-command>"
            echo "Example: gos ERROR go test ./..."
            return 1
        end
        set -l search_term $argv[1]
        set -e argv[1]
        command go $argv 2>&1 | splash -s "$search_term"
    end

    function gor --description "Run go command with regex highlighting"
        if test (count $argv) -lt 2
            echo "Usage: gor <regex> <go-command>"
            echo "Example: gor 'FAIL|ERROR' go test ./..."
            return 1
        end
        set -l regex $argv[1]
        set -e argv[1]
        command go $argv 2>&1 | splash -r "$regex"
    end

    # Generic helper for any command with search highlighting
    function runs --description "Run any command with splash search highlighting"
        if test (count $argv) -lt 2
            echo "Usage: runs <search-term> <command...>"
            echo "Example: runs ERROR npm test"
            return 1
        end
        set -l search_term $argv[1]
        set -e argv[1]
        $argv 2>&1 | splash -s "$search_term"
    end

    function runr --description "Run any command with splash regex highlighting"
        if test (count $argv) -lt 2
            echo "Usage: runr <regex> <command...>"
            echo "Example: runr '[45]\\d\\d' curl api.example.com"
            return 1
        end
        set -l regex $argv[1]
        set -e argv[1]
        $argv 2>&1 | splash -r "$regex"
    end

    # Function to set splash arguments for the current session
    function splash-set --description "Set splash arguments for automatic commands"
        if test (count $argv) -eq 0
            if set -q SPLASH_ARGS
                echo "Current SPLASH_ARGS: $SPLASH_ARGS"
            else
                echo "No SPLASH_ARGS set"
            end
            echo ""
            echo "Usage: splash-set <args>"
            echo "Examples:"
            echo "  splash-set -s ERROR        # Highlight ERROR in all auto-splash commands"
            echo "  splash-set -r '[45]\\d\\d'  # Highlight 4xx and 5xx HTTP codes"
            echo "  splash-set --dark          # Force dark theme"
            echo "  splash-set ''              # Clear splash arguments"
        else if test "$argv[1]" = ""
            set -e SPLASH_ARGS
            echo "SPLASH_ARGS cleared"
        else
            set -gx SPLASH_ARGS $argv
            echo "SPLASH_ARGS set to: $argv"
        end
    end

    # Alias for convenience
    alias splash-clear="splash-set ''"
end

alias n=nvim
alias nvm="env NVIM_APPNAME=nvim-mini nvim" # Minimal Neovim config
alias fixterm="stty sane"
alias footyres="$HOME/dotfiles/scripts/bin/footyres" # Football results CLI

# Obsidian and Productivity Aliases
# Moved to functions/: obs, todo, gis, gisls, gisdel, ssmc, f, gx, e, tb, aws-sso, assume, aws-whoami, s3grep, s3-logs, gd-view, ct-view, s3-dates, s3-browse, logs, gwtaf, gwtabf, gco, gstash, dps, dimg, gwtl, gwtr, _atuin_search*

# Kubernetes aliases
alias kctx="kubie ctx"
alias kns="kubie ns"

# GitHub Gist aliases (enhanced with fzf functions below)
alias gispub="gis"
alias gispriv="gh gist create"

# System monitoring aliases
alias top="btop" # Use btop as default process viewer
alias htop="htop --tree" # Show htop with tree view by default
# alias ps="procs"  # Disabled - procs is not a drop-in ps replacement (-p means --pager, not PID filter)
alias pst="procs --tree" # Process tree view
alias psg="procs | grep" # Search processes
alias net="sudo bandwhich" # Network monitoring (requires sudo)
alias dig="doggo" # Modern DNS lookup
alias dns="doggo" # Alternative DNS alias

# Security & DevSecOps Tools
alias scan="trivy" # Vulnerability scanner
alias vuln="grype" # Container vulnerability scanner
alias sbom="syft" # Generate SBOM
alias tfscan="tfsec" # Terraform security scanner
alias iacscan="checkov" # IaC security scanner
alias semscan="semgrep" # Static analysis
alias dockerlint="hadolint" # Dockerfile linter

# Kubernetes & Container Tools
# Use kubecolor for colorized kubectl output if available
if test -x $_brew/kubecolor
    alias kubectl="kubecolor"
end
alias k="kubectl" # Kubernetes CLI shorthand
alias kc="kubectx" # Quick context switching
alias kn="kubens" # Quick namespace switching
alias kx="kubie ctx" # Switch kubernetes context with kubie (alternative)
alias kns="kubie ns" # Switch namespace with kubie (alternative)
alias kdive="dive" # Docker image explorer
alias kctop="ctop" # Container metrics

# Kubernetes shortcuts
alias kgp="kubectl get pods"
alias kgs="kubectl get svc"
alias kgd="kubectl get deployment"
alias kgn="kubectl get nodes"
alias kdp="kubectl describe pod"
alias kds="kubectl describe svc"
alias kdd="kubectl describe deployment"
alias kdn="kubectl describe node"
alias kaf="kubectl apply -f"
alias kdf="kubectl delete -f"
alias kl="kubectl logs"
alias klf="kubectl logs -f"
alias ke="kubectl exec -it"

# Local Kubernetes clusters (using Colima + k3d)
# k3d shortcuts
alias k3dc="k3d cluster"
alias k3dcreate="k3d cluster create"
alias k3dlist="k3d cluster list"
alias k3ddel="k3d cluster delete"
alias k3s="~/dotfiles/scripts/k3s-setup.sh"

# kind shortcuts
alias kindc="kind create cluster"
alias kindl="kind get clusters"
alias kindd="kind delete cluster"

# Better File/System Tools
alias du="dust" # Better disk usage
alias ncdu="ncdu --color dark" # NCurses disk usage
# alias sed="sd"  # Disabled - breaks completion scripts that expect real sed
alias sedd="sd" # Use 'sedd' for the sd tool instead
# alias cut="choose"  # Disabled - choose-rust is not a drop-in replacement for cut (different CLI interface)
alias loc="tokei" # Code statistics
alias duf="duf" # Better df

# Network Tools
alias http="xh" # Friendly HTTP client
alias grpc="grpcurl" # gRPC client
alias trace="mtr" # Better traceroute
alias ping="gping" # Ping with graph
alias bench="hyperfine" # Command benchmarking
alias load="oha" # HTTP load testing

# Infrastructure Tools
alias tf="terraform" # Terraform shorthand
alias tg="terragrunt" # Terragrunt shorthand
alias tfdoc="terraform-docs" # Terraform docs
alias tfcost="infracost" # Infrastructure cost

# Monitoring & Performance
alias mon="glances" # System monitoring
alias lognav="lnav" # Log navigator
alias flame="flamegraph" # Performance visualization

# Development Tools
alias watch="watchexec" # Execute on file change
alias j="just" # Command runner
alias t="task" # Task runner
alias act="act --container-architecture linux/amd64" # GitHub Actions locally with ARM64 compatibility

# AI Tools
# Use 'ccr code' or just 'ccr' to start Claude Code Router
alias claude-router="command ccr code" # Alternative alias for Claude Code Router

# Utility aliases
alias wea="curl --silent wttr.in/Didsbury_uk | grep -v Follow"
alias save="~/sesh.sh save"
alias rest="~/sesh.sh restore"
alias tr="clear; ~/dotfiles/scripts/tmux/tmux-smart-restore.sh"
alias ts="tmux run-shell '~/.tmux/plugins/tmux-resurrect/scripts/save.sh'"
alias tk="~/dotfiles/scripts/tmux/tmux-safe-kill-server.sh" # Safe kill with auto-save
alias tkf="tmux kill-server" # Force kill without save (use with caution)

# Security aliases
alias vetf="vet --force" # Force execution (use with caution)

# Git worktree aliases
alias gwta="git worktree add"
alias gwtab="git worktree add -b"
# alias gwtl="git worktree list"  # Replaced with fzf function below
# alias gwtr="git worktree remove"  # Replaced with fzf function below
alias gwtp="git worktree prune"
alias gwtm="git worktree move"

# Worktree + Devcontainer integration aliases
alias gwtd="gwt-dev" # Create worktree with devcontainer
alias gwtde="gwt-dev --exec" # Create and exec into
alias gwtc="gwt-claude" # Launch Claude in worktree
alias gwts="gwt-status" # Show worktree + devcontainer status
alias gwtclean="gwt-cleanup" # Cleanup stale devcontainer instances
functions -q gwtt; and functions -e gwtt # Drop old alias function when reloading config.
# gwtt is an autoloaded function so default launches can detach from the caller pane.
alias gwtq="gwt-queue" # Ticket queue management
alias gwtdoc="gwt-doctor" # Agent orchestration health check
alias csub="claude-sub" # Claude subscription profiles
alias cr="claude-resume" # FZF session picker for claude --resume

# Ticket execution aliases
alias tex="ticket-execute" # Execute ticket autonomously
alias texs="ticket-execute --status ." # Check status
alias texw="ticket-execute --watch ." # Watch for completion

# Graphite merge queue aliases
alias gtq="gt-queue" # Merge queue status
alias gtql="gt-queue list" # List queued PRs
alias gtqe="gt-queue enqueue" # Enqueue current PR
alias gtqd="gt-queue dequeue" # Dequeue current PR
alias gtqm="gt-queue merge" # Merge via Graphite
alias gtqs="gt-queue submit --stack" # Submit + merge-when-ready
alias gtqo="gt-queue open" # Open dashboard
alias gtqw="gt-queue watch" # Auto-refresh queue status
alias gtqr="gt-queue retry" # Re-enqueue failed PR
alias gts="gt-stack" # Stack viewer
alias gtsi="gt-stack --interactive" # Interactive stack viewer
alias gtss="gt submit --stack" # Submit entire stack

# Git local exclude management
alias gls="gitlocal-setup"
alias glsf="gitlocal-setup --force"
alias glsd="gitlocal-setup --dry-run"

# Functions moved to separate files in functions/ for autoloading
# AWS, Git, S3, and Atuin functions moved

# Note: Additional git+fzf functionality is provided in conf.d/plugins.fish

# FZF-Atuin integration - Custom history search
# Override the default Ctrl-R binding from plugins.fish
bind \cr atuin_fzf_search
bind -M insert \cr atuin_fzf_search

# Ensure fifc Tab binding takes precedence over autopair.fish
# This rebinds Tab to the fifc/git/docker wrapper after all plugins have loaded
if functions -q _fifc_or_fzf
    bind \t _fifc_or_fzf
    bind -M insert \t _fifc_or_fzf
end

# PATH is managed in .config/fish/paths.fish with one batched update.

# Opencode LSP integration with Nix
# Prevent Opencode from downloading its own LSP servers
# Uses Nix-managed LSP servers instead (from PATH)
set -gx OPENCODE_DISABLE_LSP_DOWNLOAD true
