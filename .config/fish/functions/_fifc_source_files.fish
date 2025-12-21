function _fifc_source_files -d "Return a command to recursively find files"
    set -l path (_fifc_path_to_complete | string escape)
    set -l hidden (string match "*." "$path")

    if string match --quiet -- '~*' "$fifc_query"
        set -e fifc_query
    end

    if type -q fd
        if _fifc_test_version (fd --version) -ge "8.3.0"
            set fd_custom_opts --strip-cwd-prefix
        end

        if test "$path" = {$PWD}/
            # Current dir: output relative paths
            echo "fd . $fifc_fd_opts --color=always $fd_custom_opts"
        else if test "$path" = "."
            # Hidden files in current dir: output relative paths
            echo "fd . $fifc_fd_opts --color=always --hidden $fd_custom_opts"
        else if test -n "$hidden"
            # External dir with hidden: output tilde paths (~/path/file)
            echo "fd . $fifc_fd_opts --color=always --hidden --base-directory $path $fd_custom_opts | while read -l line; printf '%s/%s\\n' (string replace \$HOME '~' $path | string replace -r '/\$' '') \"\$line\"; end"
        else
            # External dir: output tilde paths (~/path/file)
            echo "fd . $fifc_fd_opts --color=always --base-directory $path $fd_custom_opts | while read -l line; printf '%s/%s\\n' (string replace \$HOME '~' $path | string replace -r '/\$' '') \"\$line\"; end"
        end
    else if test -n "$hidden"
        # Use sed to strip cwd prefix
        echo "find . $path $fifc_find_opts ! -path . -print 2>/dev/null | sed 's|^\./||'"
    else
        # Exclude hidden directories
        echo "find . $path $fifc_find_opts ! -path . ! -path '*/.*' -print 2>/dev/null | sed 's|^\./||'"
    end
end
