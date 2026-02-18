function tfcostf --description "Estimate infrastructure costs with infracost"
    if not test -x /opt/homebrew/bin/infracost
        echo "infracost not installed"
        return 1
    end

    set -l actions breakdown diff configure

    set -l selected (printf '%s\n' $actions | fzf \
        --prompt="Select infracost action: " \
        --height=40% \
        --border)

    switch "$selected"
        case breakdown
            infracost breakdown --path .
        case diff
            infracost diff --path .
        case configure
            infracost configure
    end
end
