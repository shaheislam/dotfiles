# Bash completions for aimux
_aimux() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"
    commands="new status run attach kill merge pr init doctor queue log notify daemon version help"

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
    merge) COMPREPLY=($(compgen -W "--pr --squash --message --delete --no-delete --dry-run --help" -- "$cur")) ;;
    pr) COMPREPLY=($(compgen -W "--title --body --draft --base --reviewer --label --delete --open --help" -- "$cur")) ;;
    init) COMPREPLY=($(compgen -W "--force --help" -- "$cur")) ;;
    log) COMPREPLY=($(compgen -W "--follow --all --clear --help" -- "$cur")) ;;
    notify) COMPREPLY=($(compgen -W "--bell --osc --native --webhook --all --title --help" -- "$cur")) ;;
    esac

    # Provider values for --provider
    if [[ "$prev" == "--provider" ]]; then
        COMPREPLY=($(compgen -W "claude codex ollama aider gemini opencode cline amp cursor copilot" -- "$cur"))
        return 0
    fi
}
complete -F _aimux aimux
