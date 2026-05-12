# Keep GPG pinentry attached to the current terminal, including tmux panes.
if status is-interactive; and tty -s
    set -gx GPG_TTY (tty)

    if test -x /opt/homebrew/bin/gpg-connect-agent
        /opt/homebrew/bin/gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
    else if type -q gpg-connect-agent
        gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
    end
end
