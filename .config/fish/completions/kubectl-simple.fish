# Simple kubectl completions registration

# Register completions for kubectl and aliases
for cmd in kubectl k kubecolor
    # Use simple completion function for all subcommands
    # Note: The function is named kubectl_simple_complete, not kubectl_complete_simple
    complete -c $cmd -f -a "(kubectl_simple_complete)"

    # Also provide basic subcommand completions
    complete -c $cmd -f -n "__fish_use_subcommand" -a "get describe delete logs exec port-forward apply create"
end