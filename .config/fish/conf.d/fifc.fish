# Private
set -gx _fifc_comp_count 0
set -gx _fifc_unordered_comp
set -gx _fifc_ordered_comp

if status is-interactive
    # Keybindings
    set -qU fifc_keybinding
    or set -U fifc_keybinding \t

    set -qU fifc_open_keybinding
    or set -U fifc_open_keybinding ctrl-o

    # Wrapper to use fzf-git.sh for git commands, FIFC for everything else
    function _fifc_or_git_fzf
        set -l cmd (commandline -opc)
        if test (count $cmd) -gt 0; and test "$cmd[1]" = "git"
            _git_fzf_tab_complete
        else
            _fifc
        end
    end

    for mode in default insert
        bind --mode $mode \t _fifc_or_git_fzf
        bind --mode $mode $fifc_keybinding _fifc_or_git_fzf
    end

    # Set sources rules
    fifc \
        -n 'test "$fifc_group" = "directories"' \
        -s _fifc_source_directories
    fifc \
        -n 'test "$fifc_group" = "files"' \
        -s _fifc_source_files
    fifc \
        -n 'test "$fifc_group" = processes' \
        -s 'ps -ax -o pid=,command='
end

# Load fifc preview rules only when fish is launched fzf
if set -q _fifc_launched_by_fzf
    # Custom kubectl preview rule - must come first to match before generic rules
    fifc \
        -n 'string match -q "kubectl *" "$fifc_commandline"; or string match -q "k *" "$fifc_commandline"' \
        -p _fifc_kubectl_preview

    # Builtin preview/open commands
    fifc \
        -n 'test "$fifc_group" = "options"' \
        -p _fifc_preview_opt \
        -o _fifc_open_opt
    fifc \
        -n 'test \( -n "$fifc_desc" -o -z "$fifc_commandline" \); and type -q -f -- "$fifc_candidate"' \
        -r '^(?!\\w+\\h+)' \
        -p _fifc_preview_cmd \
        -o _fifc_open_cmd
    fifc \
        -n 'test -n "$fifc_desc" -o -z "$fifc_commandline"' \
        -r '^(functions)?\\h+' \
        -p _fifc_preview_fn \
        -o _fifc_open_fn
    fifc \
        -n 'test -f "$fifc_candidate"' \
        -p _fifc_preview_file \
        -o _fifc_open_file
    fifc \
        -n 'test -d "$fifc_candidate"' \
        -p _fifc_preview_dir \
        -o _fifc_open_dir
    fifc \
        -n 'test "$fifc_group" = processes -a (ps -p (_fifc_parse_pid "$fifc_candidate") &>/dev/null)' \
        -p _fifc_preview_process \
        -o _fifc_open_process \
        -e '^\\h*([0-9]+)'
end


# Fisher
function _fifc_uninstall --on-event fifc_uninstall
end
