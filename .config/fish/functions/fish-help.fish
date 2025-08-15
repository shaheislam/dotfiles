function fish-help --description "Show custom Fish commands and features"
    echo "🐟 Custom Fish Commands & Features"
    echo "================================="
    echo ""

    echo "📚 History Search (Atuin + FZF):"
    echo "  Ctrl+R     - Search command history with FZF"
    echo "  Ctrl+D     - Filter by current directory"
    echo "  Ctrl+G     - Show global history (all directories)"
    echo "  Ctrl+S     - Show session history"
    echo "  Up Arrow   - Directory-specific history (native Atuin)"
    echo ""

    echo "🔑 SSH Key Management:"
    echo "  ssh-switch <key>  - Switch between SSH keys"
    echo "    personal        - Personal GitHub (shaheislam)"
    echo "    dfe            - DFE GitHub (shaheislamdfe)"
    echo "    petlab         - Bitbucket/PetLab"
    echo "  ssh-auto (ssa)    - Auto-switch based on current repo"
    echo "  git-check-identity (gci) - Check if using correct SSH key"
    echo ""

    echo "🚀 Git Enhancements:"
    echo "  git-smart         - Git wrapper with SSH key validation"
    echo "  gwtaf <branch>    - Add worktree for existing branch"
    echo "  gwtabf <branch>   - Create new branch + worktree"
    echo ""

    echo "📁 Navigation & Tools:"
    echo "  z <path>          - Jump to directory (zoxide)"
    echo "  la, l             - List files with icons (eza)"
    echo "  cat               - View files with syntax highlighting (bat)"
    echo "  lg                - LazyGit"
    echo "  ld                - LazyDocker"
    echo ""

    echo "🔧 Other Utilities:"
    echo "  f                 - Open file with FZF"
    echo "  ssmc [profile]    - AWS SSM connect with FZF"
    echo "  aws-sso [profile] - AWS SSO login"
    echo "  tb                - Pipe to termbin and copy URL"
    echo "  fixterm           - Fix terminal (stty sane)"
    echo ""

    echo "💡 Tips:"
    echo "  - In WezTerm, arrow keys work in Ctrl+R history search"
    echo "  - SSH keys are managed via SSH agent for security"
    echo "  - Git abbreviations: g, ga, gaa, gc, gco, gd, gp, gst, etc."
    echo "  - Kubectl shortcuts: k, kgp, kgs, kgd, kaf, klog, kexec"
end

# Create an alias for convenience
abbr -a fh fish-help
