function fdiff --description "Diff two files in Neovim"
    set -l file1 $argv[1]
    set -l file2 $argv[2]

    # If first file not provided, use fzf
    if test -z "$file1"
        set file1 (fzf --prompt="Select first file> " --header="Pick the FIRST file to compare")
        test -z "$file1"; and return 0
    end

    # If second file not provided, use fzf
    if test -z "$file2"
        set file2 (fzf --prompt="Select second file> " --header="Pick the SECOND file to compare with: $file1")
        test -z "$file2"; and return 0
    end

    # Validate files exist
    if not test -f "$file1"
        echo "Error: File not found: $file1"
        return 1
    end

    if not test -f "$file2"
        echo "Error: File not found: $file2"
        return 1
    end

    echo "Diffing: $file1 ↔ $file2"
    nvim -d "$file1" "$file2"
end
