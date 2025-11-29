function gdc -d "Compare two commits/branches with DiffviewOpen using fzf picker"
    # Get the path to fzf-git.sh
    set -l fzf_git_sh_path (realpath (status dirname))

    # Build commands with the path resolved
    set -l hashes_cmd "SHELL=bash bash '$fzf_git_sh_path/fzf-git.sh' --run hashes 2>/dev/null"
    set -l branches_cmd "SHELL=bash bash '$fzf_git_sh_path/fzf-git.sh' --run branches 2>/dev/null"

    # Helper function to run fzf with view switching
    # Ctrl-H → commits/hashes view, Ctrl-B → branches view
    function _gdc_pick --argument-names prompt initial_view hashes_cmd branches_cmd
        # Determine initial command
        set -l initial_cmd
        set -l header_text
        if test "$initial_view" = branches
            set initial_cmd $branches_cmd
            set header_text "Branches │ ctrl-h: commits │ ctrl-b: branches"
        else
            set initial_cmd $hashes_cmd
            set header_text "Commits │ ctrl-h: commits │ ctrl-b: branches"
        end

        # Run fzf with reload bindings
        eval $initial_cmd | fzf \
            --prompt="$prompt" \
            --header="$header_text" \
            --bind="ctrl-h:reload($hashes_cmd)+change-header(Commits │ ctrl-h: commits │ ctrl-b: branches)" \
            --bind="ctrl-b:reload($branches_cmd)+change-header(Branches │ ctrl-h: commits │ ctrl-b: branches)" \
            --ansi \
            --no-sort \
            --preview-window='right,50%,border-left' \
            --preview="git log --oneline --graph --color=always -15 {1}" \
            | string trim
    end

    # Pick first commit/branch (base)
    echo "Select BASE (older)..."
    set -l base (_gdc_pick "BASE> " hashes "$hashes_cmd" "$branches_cmd")

    if test -z "$base"
        echo "Cancelled - no base selected"
        functions -e _gdc_pick
        return 1
    end

    # Pick second commit/branch (compare)
    echo "Select COMPARE (newer)..."
    set -l compare (_gdc_pick "COMPARE> " hashes "$hashes_cmd" "$branches_cmd")

    if test -z "$compare"
        echo "Cancelled - no compare selected"
        functions -e _gdc_pick
        return 1
    end

    # Cleanup helper function
    functions -e _gdc_pick

    # Open Neovim with DiffviewOpen
    echo "Opening diff: $base..$compare"
    nvim -c "DiffviewOpen $base..$compare"
end
