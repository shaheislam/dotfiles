# fzf-lua CLI Keybindings - Space Leader in Normal Mode
# Mirrors Neovim fzf-lua keybindings with exact parity
#
# Usage: Press ESC to enter normal mode, then <Space>ff for files
#
# Output is JSON - specialized functions extract paths via jq and perform actions
#
# Keybinding Reference (Normal Mode - press ESC first):
#   <Space>ff  - Find files → open in nvim
#   <Space>fF  - Find files from home → open in nvim
#   <Space>cd  - Zoxide directories → cd to dir
#   <Space>fg  - Live grep → open in nvim
#   <Space>fr  - Recent files (oldfiles) → open in nvim
#   <Space>fR  - Recent files global → open in nvim
#   <Space>fz  - All pickers (builtin)
#
# Git (<Space>g prefix):
#   <Space>gg  - Git status → open in nvim
#   <Space>gf  - Git files → open in nvim
#   <Space>gl  - Git commits (log) → output SHA
#   <Space>gC  - Git file commits → select file, show history
#   <Space>gb  - Git branches → checkout
#   <Space>gs  - Git stash → apply/drop
#   <Space>gd  - Git diffview → show working dir changes
#   <Space>gD  - Git diffview picker → compare branches/commits
#   <Space>gP  - PR preview → compare to base in Diffview
#
# Inside picker: Alt-L=Local, Alt-S=Git Root, Alt-G=Global, Ctrl-Y=Copy, Ctrl-/=Preview

if status is-interactive
    # Check if nvim is available
    if command -v nvim >/dev/null 2>&1
        # Check if fzf-lua CLI exists
        set -l cli_path "$HOME/.local/share/nvim/lazy/fzf-lua/scripts/cli.lua"
        if test -n "$XDG_DATA_HOME"
            set cli_path "$XDG_DATA_HOME/nvim/lazy/fzf-lua/scripts/cli.lua"
        end

        if test -f "$cli_path"
            # ═══════════════════════════════════════════════════════════════════
            # Space + f* bindings (file pickers) - Normal mode only
            # Exact Neovim parity: ESC then <Space>ff = <leader>ff in Neovim
            # ═══════════════════════════════════════════════════════════════════

            # <Space>ff - Find files → open in nvim
            bind -M default ' ff' '_fzf_lua_files_edit'

            # <Space>fF - Find files from home → open in nvim
            bind -M default ' fF' '_fzf_lua_files_home_edit'

            # <Space>cd - Zoxide directories → cd to dir
            bind -M default ' cd' '_fzf_lua_zoxide'

            # <Space>fg - Live grep → open in nvim
            bind -M default ' fg' '_fzf_lua_grep_edit'

            # <Space>fr - Recent files → open in nvim
            bind -M default ' fr' '_fzf_lua_oldfiles_edit'

            # <Space>fR - Recent files global → open in nvim
            bind -M default ' fR' '_fzf_lua_oldfiles_edit cwd_only=false'

            # <Space>fz - All pickers (builtin)
            bind -M default ' fz' '_fzf_lua_picker_edit builtin'

            # ═══════════════════════════════════════════════════════════════════
            # Space + g* bindings (git pickers) - Normal mode only
            # ═══════════════════════════════════════════════════════════════════

            # <Space>gg - Git status → open in nvim
            bind -M default ' gg' '_fzf_lua_git_status_edit'

            # <Space>gf - Git files → open in nvim
            bind -M default ' gf' '_fzf_lua_git_files_edit'

            # <Space>gl - Git commits/log → output SHA
            bind -M default ' gl' '_fzf_lua_git_commits'

            # <Space>gC - Git file commits → select file, show history
            bind -M default ' gC' '_fzf_lua_git_bcommits_picker'

            # <Space>gb - Git branches → checkout
            bind -M default ' gb' '_fzf_lua_git_branches'

            # <Space>gs - Git stash → apply/drop
            bind -M default ' gs' '_fzf_lua_git_stash'

            # <Space>gd - Git diffview → show working dir changes
            bind -M default ' gd' '_fzf_lua_git_diffview'

            # <Space>gD - Git diffview picker → compare branches/commits
            bind -M default ' gD' '_fzf_lua_git_diffview_picker'

            # <Space>gP - PR preview → compare to base in Diffview
            bind -M default ' gP' '_fzf_lua_git_pr_preview'

            # ═══════════════════════════════════════════════════════════════════
            # Help binding
            # ═══════════════════════════════════════════════════════════════════

            # <Space>f? - Show help
            bind -M default ' f?' '_fzf_lua_keybindings_help; commandline -f repaint'
        end
    end
end
