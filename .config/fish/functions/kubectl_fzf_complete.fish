# Optional FZF-powered kubectl completions
# This provides FZF selection on top of the enhanced completions

# Set this to enable FZF for kubectl completions
set -g kubectl_use_fzf true

function kubectl_fzf_complete --description "FZF-powered kubectl completion"
    # Get completions from enhanced function
    set -l completions (kubectl_enhanced_complete)

    # If no completions or FZF disabled, return raw completions
    if test (count $completions) -eq 0; or test "$kubectl_use_fzf" != "true"
        printf '%s\n' $completions
        return
    end

    # Determine context for better FZF presentation
    set -l cmd (commandline -opc)
    set -l subcommand ""
    set -l resource_type ""

    # Parse command to get context
    for arg in $cmd[2..-1]
        if not string match -q -- '-*' $arg
            if test -z "$subcommand"
                set subcommand $arg
            else if test -z "$resource_type"
                set resource_type $arg
                break
            end
        end
    end

    # Build FZF prompt based on context
    set -l prompt "Select: "
    if test -n "$resource_type"
        set prompt "Select $resource_type: "
    else if test -n "$subcommand"
        set prompt "Select for $subcommand: "
    end

    # Determine if we should show preview (for resource selections)
    set -l show_preview false
    set -l preview_cmd ""

    # Check if we're selecting a resource (not a flag or subcommand)
    if not string match -q -- '-*' $completions[1] 2>/dev/null
        if test -n "$resource_type"; or contains -- $subcommand logs exec describe get delete
            set show_preview true

            # Build preview command based on context
            set -l namespace (_kubectl_extract_namespace $cmd)
            set -l ns_flag ""
            if test "$namespace" != "default"; and test "$namespace" != "all"
                set ns_flag "--namespace=$namespace"
            end

            # Simple describe preview (not full YAML to keep it light)
            set preview_cmd "kubectl $ns_flag describe $resource_type {} 2>/dev/null | head -20"

            # Special cases for certain resources
            if test -z "$resource_type"; and test "$subcommand" = "logs"
                set preview_cmd "kubectl $ns_flag get pod {} -o wide 2>/dev/null"
            else if test -z "$resource_type"; and contains -- $subcommand exec describe
                set preview_cmd "kubectl $ns_flag get pod {} -o wide 2>/dev/null"
            end
        end
    end

    # Use FZF with or without preview
    set -l selected ""
    if test "$show_preview" = "true"; and test -n "$preview_cmd"
        set selected (printf '%s\n' $completions | \
            fzf --height=50% \
                --prompt="$prompt" \
                --preview="$preview_cmd" \
                --preview-window=right:50%:wrap \
                --bind=ctrl-/:toggle-preview)
    else
        # No preview for flags, subcommands, etc.
        set selected (printf '%s\n' $completions | \
            fzf --height=40% \
                --prompt="$prompt")
    end

    # Insert selected item if one was chosen
    if test -n "$selected"
        commandline -t "$selected"
        commandline -f repaint
    end
end

# Helper function to toggle FZF mode
function kubectl_toggle_fzf --description "Toggle FZF mode for kubectl completions"
    if test "$kubectl_use_fzf" = "true"
        set -g kubectl_use_fzf false
        echo "kubectl FZF completions disabled"
    else
        set -g kubectl_use_fzf true
        echo "kubectl FZF completions enabled"
    end
end