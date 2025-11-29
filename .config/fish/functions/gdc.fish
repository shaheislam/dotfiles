function gdc -d "Compare two commits with DiffviewOpen using fzf picker"
    # Get the path to fzf-git.sh
    set -l fzf_git_sh_path (realpath (status dirname))

    # Pick first commit (base)
    echo "Select BASE commit (older)..."
    set -l base_commit (SHELL=bash bash "$fzf_git_sh_path/fzf-git.sh" --run hashes 2>/dev/null | string trim)

    if test -z "$base_commit"
        echo "Cancelled - no base commit selected"
        return 1
    end

    # Pick second commit (compare)
    echo "Select COMPARE commit (newer)..."
    set -l compare_commit (SHELL=bash bash "$fzf_git_sh_path/fzf-git.sh" --run hashes 2>/dev/null | string trim)

    if test -z "$compare_commit"
        echo "Cancelled - no compare commit selected"
        return 1
    end

    # Open Neovim with DiffviewOpen
    echo "Opening diff: $base_commit..$compare_commit"
    nvim -c "DiffviewOpen $base_commit..$compare_commit"
end
