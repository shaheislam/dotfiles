function awsp --description "Switch AWS profile with fzf"
    set -l profiles (aws configure list-profiles 2>/dev/null)
    if test -z "$profiles"
        echo "No AWS profiles found"
        return 1
    end

    set -l selected (printf '%s\n' $profiles | fzf \
        --prompt="Select AWS profile: " \
        --height=40% \
        --border \
        --preview='aws configure list --profile {}')

    if test -n "$selected"
        set -gx AWS_PROFILE $selected
        echo "Switched to AWS profile: $selected"
        aws sts get-caller-identity
    end
end
