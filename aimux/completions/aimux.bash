# Bash completions for aimux
_aimux() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"
    commands="new status run attach kill doctor queue notify daemon version help"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return 0
    fi

    case "${COMP_WORDS[1]}" in
    daemon) COMPREPLY=($(compgen -W "start stop status poll" -- "$cur")) ;;
    queue) COMPREPLY=($(compgen -W "add list start stop status help" -- "$cur")) ;;
    new) COMPREPLY=($(compgen -W "--new --exec --no-devcon --mount --rebuild --fast --features --help" -- "$cur")) ;;
    kill) COMPREPLY=($(compgen -W "--force --help" -- "$cur")) ;;
    run) COMPREPLY=($(compgen -W "--max --provider --command --no-devcon --mount --help" -- "$cur")) ;;
    notify) COMPREPLY=($(compgen -W "--bell --osc --native --webhook --all --title --help" -- "$cur")) ;;
    esac
}
complete -F _aimux aimux
