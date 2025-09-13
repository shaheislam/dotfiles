# Nushell Environment Configuration
# Migrated from Fish shell configuration

# Environment Variables
$env.BAT_THEME = "Catppuccin Mocha"
$env.STARSHIP_CONFIG = $"($env.HOME)/.config/starship.toml"
$env.PYTHONPATH = "/opt/homebrew/lib/python3.12/site-packages"
$env._ZO_DOCTOR = "0"  # Disable zoxide doctor warnings

# Load environment variables from .env file if it exists
def load_env_file [] {
    let env_file = $"($env.HOME)/.env"
    if ($env_file | path exists) {
        open $env_file
        | lines
        | where { |line| not ($line | str starts-with '#') and ($line | str trim | is-not-empty) }
        | each { |line|
            let parts = ($line | split column '=' key value)
            if ($parts | length) > 0 {
                let key = ($parts.0.key | str replace 'export ' '')
                let value = ($parts.0.value? | default '' | str trim --char '"')
                load-env { $key: $value }
            }
        }
    }
}

# Load .env file
load_env_file

# PATH Configuration
def update_path [] {
    # Add paths to PATH, preserving existing PATH
    let paths = [
        $"($env.HOME)/.claude/local/bin"
        $"($env.HOME)/.claude/local"
        $"($env.HOME)/dotfiles/scripts/bin"
        $"($env.HOME)/.bun/bin"
        $"($env.HOME)/.rd/bin"
        $"($env.HOME)/.cargo/bin"
        $"($env.HOME)/Library/Python/3.9/bin"
        $"($env.HOME)/.local/bin"
        $"($env.HOME)/bin"
        "/usr/local/bin"
        "/opt/homebrew/bin"
    ]
    
    # Add VS Code to PATH if it exists
    let vscode_path = "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    let paths = if ($vscode_path | path exists) {
        $paths | append $vscode_path
    } else {
        $paths
    }
    
    # Add Cursor to PATH if it exists
    let cursor_path = "/Applications/Cursor.app/Contents/Resources/app/bin"
    let paths = if ($cursor_path | path exists) {
        $paths | append $cursor_path
    } else {
        $paths
    }
    
    # Build new PATH by prepending our paths to existing PATH
    let current_path = ($env.PATH | split row (char esep))
    let new_paths = ($paths | where { |p| $p | path exists })
    let combined_path = ($new_paths | append $current_path | uniq)
    
    $env.PATH = ($combined_path | str join (char esep))
}

# Update PATH
update_path

# FZF Configuration
$env.FZF_DEFAULT_COMMAND = 'rg --files'
$env.FZF_DEFAULT_OPTS = '-m --height 50% --border'
$env.FZF_CTRL_T_COMMAND = $env.FZF_DEFAULT_COMMAND
$env.FZF_ALT_C_COMMAND = "fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# FZF Theme Colors - Catppuccin Mocha
let fg = "#cdd6f4"          # Text
let bg = "#1e1e2e"          # Base
let bg_highlight = "#313244" # Surface0
let purple = "#b4befe"       # Lavender
let blue = "#89b4fa"         # Blue
let cyan = "#89dceb"         # Sky
let green = "#a6e3a1"        # Green
let orange = "#fab387"       # Peach
let red = "#f38ba8"          # Red
let yellow = "#f9e2af"       # Yellow
let magenta = "#cba6f7"      # Mauve

$env.FZF_DEFAULT_OPTS = $"--color=fg:($fg),bg:-1,hl:($blue),fg+:($fg),bg+:($bg_highlight),hl+:($magenta),info:($yellow),prompt:($cyan),pointer:($blue),marker:($green),spinner:($cyan),header:($purple),border:($bg_highlight),preview-bg:-1,preview-fg:($fg) --height 60% --layout=reverse --border=rounded --border-label=' 🔍 Search ' --border-label-pos=3 --preview-window=right:60%:wrap:rounded --padding=1 --margin=1 --prompt='▶ ' --pointer='→' --marker='✓' --bind='ctrl-/:toggle-preview' --bind='ctrl-u:preview-page-up' --bind='ctrl-d:preview-page-down' --bind='ctrl-y:preview-up' --bind='ctrl-e:preview-down'"

$env.FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=numbers,changes --line-range=:500 {}' --border-label=' 📄 Files ' --preview-label=' Preview ' --preview-label-pos=3"

$env.FZF_ALT_C_OPTS = "--preview 'eza --tree --icons --level=2 --color=always {}' --border-label=' 📁 Directories ' --preview-label=' Tree View ' --preview-label-pos=3"

# Atuin settings
$env.ATUIN_NOBIND = "true"

# Direnv settings
$env.direnv_fish_mode = "eval_on_arrow"

# Initialize Starship prompt
# Note: Starship integration needs to be done in config.nu

# Source asdf if available
let asdf_path = "/opt/homebrew/opt/asdf/libexec/asdf.nu"
if ($asdf_path | path exists) {
    # asdf integration will be sourced in config.nu
}

# Set up config and startup paths
$env.NU_LIB_DIRS = [
    ($nu.default-config-dir | path join 'scripts')
    ($nu.data-dir | path join 'completions')
]

$env.NU_PLUGIN_DIRS = [
    ($nu.default-config-dir | path join 'plugins')
]