function gis
    if test -n "$argv[1]"
        gh gist create -p $argv[1] | grep https | tee >(clipboard_copy)
    else
        gisls
    end
end
