# Completions for assume command (Granted)
# Add AWS profile name completions

function __fish_assume_complete_profiles
    aws configure list-profiles 2>/dev/null
end

# Complete profile names for assume command
complete -c assume -f -a "(__fish_assume_complete_profiles)" -d "AWS profile"