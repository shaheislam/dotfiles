function _fifc_path_to_complete
    set -l token (string unescape -- $fifc_token)
    if test -n "$token"
        _fifc_expand_tilde "$token"
    else
        echo {$PWD}/
    end
end
