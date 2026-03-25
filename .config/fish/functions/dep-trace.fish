# Dependency chain mapper for dotfiles
# Traces what depends on a given tool/config across the repo.
# Useful before removing, upgrading, or deprecating a tool.
#
# Usage:
#   dep-trace fzf          - Show everything that depends on fzf
#   dep-trace starship      - Show starship dependents
#   dep-trace --json fzf    - JSON output for scripting
#   dep-trace --brief fzf   - One-line summary only

function dep-trace --description "Trace tool/config dependencies in dotfiles"
    set -l dotfiles_root ~/dotfiles
    set -l json_mode false
    set -l brief_mode false
    set -l tool_name ""

    # Parse args
    for arg in $argv
        switch $arg
            case --json
                set json_mode true
            case --brief
                set brief_mode true
            case '--*'
                echo "Unknown option: $arg"
                return 1
            case '*'
                set tool_name $arg
        end
    end

    if test -z "$tool_name"
        echo "Usage: dep-trace [--json|--brief] <tool-name>"
        echo ""
        echo "Traces what depends on a tool across the dotfiles repo."
        echo "Checks: Fish functions, scripts, configs, Brewfile, PATH entries."
        return 1
    end

    # --- Gather dependency data ---
    set -l fish_funcs (rg -l --no-heading "$tool_name" "$dotfiles_root/.config/fish/functions/" 2>/dev/null)
    set -l fish_conf (rg -l --no-heading "$tool_name" "$dotfiles_root/.config/fish/config.fish" "$dotfiles_root/.config/fish/conf.d/" 2>/dev/null)
    set -l scripts (rg -l --no-heading "$tool_name" "$dotfiles_root/scripts/" 2>/dev/null)
    set -l configs (rg -l --no-heading "$tool_name" "$dotfiles_root/.config/" --glob '!fish/**' 2>/dev/null)
    set -l claude_refs (rg -l --no-heading "$tool_name" "$dotfiles_root/.claude/" 2>/dev/null)
    set -l zsh_refs (rg -l --no-heading "$tool_name" "$dotfiles_root/.zshrc" "$dotfiles_root/.zprofile" 2>/dev/null)
    set -l brewfile_hit (rg --no-heading "$tool_name" "$dotfiles_root/homebrew/Brewfile" 2>/dev/null)
    set -l has_config_dir (test -d "$dotfiles_root/.config/$tool_name" && echo "yes" || echo "no")

    set -l total_refs (math (count $fish_funcs) + (count $fish_conf) + (count $scripts) + (count $configs) + (count $claude_refs) + (count $zsh_refs))

    # --- Brief mode ---
    if $brief_mode
        set -l brew_status ""
        if test -n "$brewfile_hit"
            set brew_status "brew:yes"
        else
            set brew_status "brew:no"
        end
        echo "$tool_name: $total_refs refs | fish-fn:"(count $fish_funcs)" scripts:"(count $scripts)" configs:"(count $configs)" $brew_status config-dir:$has_config_dir"
        return 0
    end

    # --- JSON mode ---
    if $json_mode
        set -l fish_funcs_json "[]"
        set -l scripts_json "[]"
        set -l configs_json "[]"
        if test (count $fish_funcs) -gt 0
            set fish_funcs_json (printf '%s\n' $fish_funcs | jq -R . | jq -s .)
        end
        if test (count $scripts) -gt 0
            set scripts_json (printf '%s\n' $scripts | jq -R . | jq -s .)
        end
        if test (count $configs) -gt 0
            set configs_json (printf '%s\n' $configs | jq -R . | jq -s .)
        end
        jq -nc \
            --arg tool "$tool_name" \
            --arg total "$total_refs" \
            --arg config_dir "$has_config_dir" \
            --arg brewfile "$brewfile_hit" \
            --argjson fish_funcs "$fish_funcs_json" \
            --argjson scripts "$scripts_json" \
            --argjson configs "$configs_json" \
            '{tool: $tool, total_refs: ($total | tonumber), has_config_dir: ($config_dir == "yes"), in_brewfile: ($brewfile != ""), fish_functions: $fish_funcs, scripts: $scripts, configs: $configs}'
        return 0
    end

    # --- Default: human-readable output ---
    echo "Dependency Trace: $tool_name"
    echo (string repeat -n 40 "─")
    echo ""

    # Brewfile
    if test -n "$brewfile_hit"
        echo "Brewfile:"
        echo "  $brewfile_hit"
    else
        echo "Brewfile: not found"
    end
    echo ""

    # Config directory
    if test "$has_config_dir" = yes
        echo "Config directory: .config/$tool_name/"
        ls "$dotfiles_root/.config/$tool_name/" 2>/dev/null | sed 's/^/  /'
    else
        echo "Config directory: none"
    end
    echo ""

    # Fish functions
    echo "Fish functions ("(count $fish_funcs)" files):"
    if test (count $fish_funcs) -gt 0
        for f in $fish_funcs
            echo "  "(string replace "$dotfiles_root/" "" $f)
        end
    else
        echo "  (none)"
    end
    echo ""

    # Fish config/conf.d
    echo "Fish config/conf.d ("(count $fish_conf)" files):"
    if test (count $fish_conf) -gt 0
        for f in $fish_conf
            echo "  "(string replace "$dotfiles_root/" "" $f)
        end
    else
        echo "  (none)"
    end
    echo ""

    # Scripts
    echo "Scripts ("(count $scripts)" files):"
    if test (count $scripts) -gt 0
        for f in $scripts
            echo "  "(string replace "$dotfiles_root/" "" $f)
        end
    else
        echo "  (none)"
    end
    echo ""

    # Other configs
    echo "Other configs ("(count $configs)" files):"
    if test (count $configs) -gt 0
        for f in $configs
            echo "  "(string replace "$dotfiles_root/" "" $f)
        end
    else
        echo "  (none)"
    end
    echo ""

    # Claude references
    if test (count $claude_refs) -gt 0
        echo "Claude references ("(count $claude_refs)" files):"
        for f in $claude_refs
            echo "  "(string replace "$dotfiles_root/" "" $f)
        end
        echo ""
    end

    # Zsh references
    if test (count $zsh_refs) -gt 0
        echo "Zsh references ("(count $zsh_refs)" files):"
        for f in $zsh_refs
            echo "  "(string replace "$dotfiles_root/" "" $f)
        end
        echo ""
    end

    # Summary
    echo (string repeat -n 40 "─")
    echo "Total: $total_refs references across the dotfiles"
    if test $total_refs -gt 10
        echo "Impact: HIGH — widespread usage, removal would be disruptive"
    else if test $total_refs -gt 3
        echo "Impact: MEDIUM — several dependents, plan removal carefully"
    else
        echo "Impact: LOW — minimal usage, safe to remove with minor cleanup"
    end
end
