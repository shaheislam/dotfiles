function gwtt --description "Launch gwt-ticket without holding the caller pane"
    set -l run_foreground false
    set -l desc_file_next false
    set -l passthrough_args

    if test (count $argv) -eq 0
        set run_foreground true
    end

    for arg in $argv
        if $desc_file_next
            if test "$arg" = "-"
                set run_foreground true
            end
            set desc_file_next false
            set -a passthrough_args "$arg"
            continue
        end

        switch $arg
            case --foreground --fg
                set run_foreground true
                continue
            case --desc-file
                set desc_file_next true
            case --help -h --status --queue --plan --verbose -v
                set run_foreground true
        end

        set -a passthrough_args "$arg"
    end

    if $run_foreground
        gwt-ticket $passthrough_args
        return $status
    end

    set -l launcher_dir "$HOME/.claude/gwtt/logs"
    mkdir -p "$launcher_dir"
    or return 1

    set -l stamp (date '+%Y%m%d-%H%M%S')
    set -l launcher_log "$launcher_dir/launch-$stamp.log"
    set -l launcher_script "$launcher_dir/launch-$stamp.fish"
    set -l display_args (string join ' ' -- $passthrough_args)
    set -l escaped_args (string escape -- $passthrough_args)

    printf '%s\n' \
        '#!/usr/bin/env fish' \
        'source "$HOME/dotfiles/.config/fish/functions/gwt-ticket.fish"' \
        "gwt-ticket $escaped_args" >$launcher_script
    chmod +x "$launcher_script"

    command nohup fish "$launcher_script" </dev/null >$launcher_log 2>&1 &
    disown 2>/dev/null

    echo "gwtt: launching $display_args in background (launcher log: $launcher_log)"
end
