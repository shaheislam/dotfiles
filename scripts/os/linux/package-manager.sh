#!/usr/bin/env bash

# Linux Package Manager Implementation
# Implements the abstract package manager interface for Linux (apt, yum, dnf, pacman)

# ============================================================================
# Distribution Detection
# ============================================================================

detect_package_manager() {
    local distro=$(detect_linux_distro)

    case "$distro" in
    ubuntu | debian | pop)
        echo "apt"
        ;;
    amzn | amazonlinux | rhel | centos | rocky | almalinux | fedora)
        if command_exists dnf; then
            echo "dnf"
        else
            echo "yum"
        fi
        ;;
    arch | manjaro)
        echo "pacman"
        ;;
    *)
        # Fallback detection
        if command_exists apt-get; then
            echo "apt"
        elif command_exists dnf; then
            echo "dnf"
        elif command_exists yum; then
            echo "yum"
        elif command_exists pacman; then
            echo "pacman"
        else
            echo "unknown"
        fi
        ;;
    esac
}

# ============================================================================
# Package Manager Interface Implementation
# ============================================================================

pm_init() {
    export LINUX_PM=$(detect_package_manager)

    if [[ "$LINUX_PM" == "unknown" ]]; then
        print_error "No supported package manager found"
        return 1
    fi

    export PACKAGE_MANAGER="$LINUX_PM"
    check_sudo
    log "Package manager initialized: $LINUX_PM (sudo: ${HAS_SUDO:-false})"
    return 0
}

pm_update() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would update package cache ($LINUX_PM)"
        return 0
    fi
    [[ "${HAS_SUDO:-false}" != "true" ]] && return 0

    print_step "Updating package cache..."

    case "$LINUX_PM" in
    apt)
        sudo apt-get update -y
        ;;
    yum | dnf)
        sudo $LINUX_PM check-update || true
        ;;
    pacman)
        sudo pacman -Sy
        ;;
    esac
}

pm_install() {
    local package=$(pm_map_package_name "$1")
    [[ -z "$package" ]] && return 1

    # Route BINARY_INSTALL: prefixed packages to the binary installer
    if [[ "$package" == BINARY_INSTALL:* ]]; then
        local binary_name="${package#BINARY_INSTALL:}"
        if declare -f install_binary >/dev/null 2>&1; then
            install_binary "$binary_name"
            return $?
        else
            log_verbose "Binary installer not available for $binary_name"
            return 1
        fi
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install $package via $LINUX_PM"
        return 0
    fi
    if [[ "${HAS_SUDO:-false}" != "true" ]]; then
        print_warning "Cannot install $package (no sudo)"
        return 1
    fi

    case "$LINUX_PM" in
    apt)
        sudo apt-get install -y "$package" 2>&1 | grep -v "is already the newest version" || return 0
        ;;
    yum | dnf)
        sudo $LINUX_PM install -y "$package"
        ;;
    pacman)
        sudo pacman -S --noconfirm "$package"
        ;;
    esac
}

pm_install_batch() {
    local packages=("$@")
    local mapped=()
    local binary_installs=()

    for pkg in "${packages[@]}"; do
        local m=$(pm_map_package_name "$pkg")
        if [[ -z "$m" ]]; then
            continue
        elif [[ "$m" == BINARY_INSTALL:* ]]; then
            binary_installs+=("${m#BINARY_INSTALL:}")
        else
            mapped+=("$m")
        fi
    done

    # Install binary packages individually
    for bin_pkg in "${binary_installs[@]}"; do
        if declare -f install_binary >/dev/null 2>&1; then
            install_binary "$bin_pkg" || log_verbose "Binary install failed for $bin_pkg"
        fi
    done

    # Install system packages in batch
    [[ ${#mapped[@]} -eq 0 ]] && return 0

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install batch via $LINUX_PM: ${mapped[*]}"
        return 0
    fi
    [[ "${HAS_SUDO:-false}" != "true" ]] && return 1

    case "$LINUX_PM" in
    apt)
        sudo apt-get install -y "${mapped[@]}"
        ;;
    yum | dnf)
        sudo $LINUX_PM install -y "${mapped[@]}"
        ;;
    pacman)
        sudo pacman -S --noconfirm "${mapped[@]}"
        ;;
    esac
}

pm_is_installed() {
    local package=$(pm_map_package_name "$1")

    # BINARY_INSTALL: packages — check if command exists
    if [[ "$package" == BINARY_INSTALL:* ]]; then
        command -v "${package#BINARY_INSTALL:}" &>/dev/null
        return $?
    fi

    case "$LINUX_PM" in
    apt)
        dpkg -l "$package" 2>/dev/null | grep -q "^ii"
        ;;
    yum | dnf)
        $LINUX_PM list installed "$package" &>/dev/null
        ;;
    pacman)
        pacman -Q "$package" &>/dev/null
        ;;
    esac
}

pm_search() {
    case "$LINUX_PM" in
    apt)
        apt-cache search "$1"
        ;;
    yum | dnf)
        $LINUX_PM search "$1"
        ;;
    pacman)
        pacman -Ss "$1"
        ;;
    esac
}

pm_remove() {
    local package=$(pm_map_package_name "$1")
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would remove $package via $LINUX_PM"
        return 0
    fi
    [[ "${HAS_SUDO:-false}" != "true" ]] && return 1

    case "$LINUX_PM" in
    apt)
        sudo apt-get remove -y "$package"
        ;;
    yum | dnf)
        sudo $LINUX_PM remove -y "$package"
        ;;
    pacman)
        sudo pacman -R --noconfirm "$package"
        ;;
    esac
}

pm_cleanup() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would clean package manager caches ($LINUX_PM)"
        return 0
    fi
    [[ "${HAS_SUDO:-false}" != "true" ]] && return 0

    case "$LINUX_PM" in
    apt)
        sudo apt-get autoremove -y
        sudo apt-get autoclean
        ;;
    yum | dnf)
        sudo $LINUX_PM clean all
        ;;
    pacman)
        sudo pacman -Sc --noconfirm
        ;;
    esac
}

pm_map_package_name() {
    local generic=$1

    # Skip macOS-only tools on Linux
    case "$generic" in
    reattach-to-user-namespace | mas | sketchybar | choose-rust)
        echo ""
        return 0
        ;;
    esac

    case "$LINUX_PM" in
    apt)
        case "$generic" in
        # Build tools
        build-essential) echo "build-essential" ;;

        # Core CLI tools with name variations
        fd) echo "fd-find" ;;
        bat) echo "bat" ;;
        golang) echo "golang-go" ;;
        nodejs) echo "nodejs" ;;
        python) echo "python3" ;;
        python@3.11) echo "python3.11" ;;

        # Tools available in Ubuntu repos
        git | curl | wget | stow | tmux | neovim | tree-sitter-cli) echo "$generic" ;;
        ripgrep | fzf | jq | yq | htop | tree) echo "$generic" ;;
        direnv | thefuck | asciinema | fish | terraform) echo "$generic" ;;
        node | pnpm | awscli | kubectl | imagemagick) echo "$generic" ;;
        redis | graphviz | w3m | urlview | shellcheck | shfmt | gh | pipx) echo "$generic" ;;
        gitleaks | cosign | hadolint | helm | stern | nmap | tcpdump | httpie) echo "$generic" ;;
        mtr | pandoc | just) echo "$generic" ;;

        # Container tools
        colima) echo "" ;; # Colima is macOS-specific, use Docker directly

        # Tools requiring binary installation from GitHub releases
        eza | zoxide | starship | yazi | bottom | btop | procs | dust | duf)
            echo "BINARY_INSTALL:$generic"
            ;;
        mise | kubie | lazydocker | terraform-docs | terragrunt)
            echo "BINARY_INSTALL:$generic"
            ;;
        uv | glow | gemini-cli | splash | onefetch)
            echo "BINARY_INSTALL:$generic"
            ;;
        granted | kustomize | velero | argocd | flux)
            echo "BINARY_INSTALL:$generic"
            ;;
        tflint | infracost | minikube | k3d | kind | kubectx)
            echo "BINARY_INSTALL:$generic"
            ;;
        grpcurl | pulumi | act | task | jj)
            echo "BINARY_INSTALL:$generic"
            ;;
        bandwhich | doggo | fastfetch | trivy | syft | grype)
            echo "BINARY_INSTALL:$generic"
            ;;
        tfsec | checkov | semgrep | nuclei | sops | age)
            echo "BINARY_INSTALL:$generic"
            ;;
        dive | ctop | gping | hyperfine | oha | glances | lnav)
            echo "BINARY_INSTALL:$generic"
            ;;
        curlie | xh | skopeo | wrk | watchexec | entr)
            echo "BINARY_INSTALL:$generic"
            ;;
        sd | tokei | ncdu | commitizen)
            echo "BINARY_INSTALL:$generic"
            ;;
        git-delta) echo "BINARY_INSTALL:git-delta" ;;

        # Language runtimes - complex installations
        go) echo "golang-go" ;;
        rust) echo "BINARY_INSTALL:rust" ;;       # Use rustup
        crystal) echo "BINARY_INSTALL:crystal" ;; # Not in standard repos
        bun) echo "BINARY_INSTALL:bun" ;;

        # Development tools
        asdf) echo "BINARY_INSTALL:asdf" ;;
        stylua) echo "BINARY_INSTALL:stylua" ;;
        black) echo "python3-black" ;;
        isort) echo "python3-isort" ;;
        tmuxinator) echo "tmuxinator" ;;
        luarocks) echo "luarocks" ;;

        # Additional system tools
        fswatch) echo "BINARY_INSTALL:fswatch" ;; # inotify-tools alternative
        ffmpegthumbnailer) echo "ffmpegthumbnailer" ;;
        unar) echo "unar" ;;

        # Azure tools
        azure-cli) echo "BINARY_INSTALL:azure-cli" ;; # Use Microsoft repo
        kubelogin) echo "BINARY_INSTALL:kubelogin" ;;

        # Observability tools not in standard repos
        e1s) echo "BINARY_INSTALL:e1s" ;;

        # Special cases — not system packages
        zsh-vi-mode) echo "" ;;          # Oh My Zsh plugin, not package
        tmux-fingers) echo "" ;;         # tmux plugin, not package
        choose | extract_url) echo "" ;; # macOS-only tools
        ollama) echo "" ;;               # Has its own installer (setup-selfhost-llm.sh)
        flamegraph) echo "" ;;           # Perl script, install via cargo/cpan
        atuin) echo "BINARY_INSTALL:atuin" ;;
        carapace) echo "BINARY_INSTALL:carapace" ;;
        ueberzugpp) echo "BINARY_INSTALL:ueberzugpp" ;;

        # Default: try package name as-is
        *) echo "$generic" ;;
        esac
        ;;
    yum | dnf)
        case "$generic" in
        # Build tools
        build-essential) echo "@development" ;;

        # Core CLI tools with name variations
        fd) echo "fd-find" ;;
        bat) echo "bat" ;;
        golang) echo "golang" ;;
        nodejs) echo "nodejs" ;;
        python) echo "python3" ;;
        python@3.11) echo "python3.11" ;;

        # Tools available in Fedora/RHEL repos (many more than Ubuntu!)
        git | curl | wget | stow | tmux | neovim | tree-sitter-cli) echo "$generic" ;;
        ripgrep | fzf | jq | yq | htop | tree | bottom) echo "$generic" ;;
        direnv | fish | terraform | node | pnpm) echo "$generic" ;;
        redis | graphviz | w3m | shellcheck | shfmt | gh | pipx) echo "$generic" ;;
        helm | nmap | tcpdump | httpie | mtr | pandoc | just) echo "$generic" ;;

        # Tools requiring binary installation
        eza | zoxide | starship | yazi | btop | procs | dust | duf)
            echo "BINARY_INSTALL:$generic"
            ;;
        mise | kubie | lazydocker | terraform-docs | terragrunt)
            echo "BINARY_INSTALL:$generic"
            ;;
        uv | glow | gemini-cli | splash | onefetch)
            echo "BINARY_INSTALL:$generic"
            ;;
        granted | kubectl | kustomize | velero | argocd | flux)
            echo "BINARY_INSTALL:$generic"
            ;;
        tflint | infracost | minikube | k3d | kind | kubectx)
            echo "BINARY_INSTALL:$generic"
            ;;
        grpcurl | pulumi | act | task | jj)
            echo "BINARY_INSTALL:$generic"
            ;;
        bandwhich | doggo | fastfetch | trivy | syft | grype)
            echo "BINARY_INSTALL:$generic"
            ;;
        tfsec | checkov | semgrep | nuclei | sops | age | git-delta)
            echo "BINARY_INSTALL:$generic"
            ;;
        dive | ctop | gping | hyperfine | oha | glances | lnav)
            echo "BINARY_INSTALL:$generic"
            ;;
        curlie | xh | skopeo | wrk | watchexec | entr)
            echo "BINARY_INSTALL:$generic"
            ;;
        sd | tokei | ncdu | commitizen | awscli)
            echo "BINARY_INSTALL:$generic"
            ;;

        # Language runtimes
        go) echo "golang" ;;
        rust) echo "BINARY_INSTALL:rust" ;;
        crystal) echo "BINARY_INSTALL:crystal" ;;
        bun) echo "BINARY_INSTALL:bun" ;;

        # Development tools
        asdf) echo "BINARY_INSTALL:asdf" ;;
        stylua) echo "BINARY_INSTALL:stylua" ;;
        black) echo "python3-black" ;;
        isort) echo "python3-isort" ;;
        tmuxinator) echo "rubygem-tmuxinator" ;;
        luarocks) echo "luarocks" ;;

        # System tools
        thefuck | asciinema | gitleaks | cosign | hadolint | stern)
            echo "BINARY_INSTALL:$generic"
            ;;
        imagemagick) echo "ImageMagick" ;;

        # Special cases — not system packages
        zsh-vi-mode) echo "" ;;          # Oh My Zsh plugin, not package
        tmux-fingers) echo "" ;;         # tmux plugin, not package
        choose | extract_url) echo "" ;; # macOS-only tools
        ollama) echo "" ;;               # Has its own installer (setup-selfhost-llm.sh)
        flamegraph) echo "" ;;           # Perl script, install via cargo/cpan
        colima) echo "" ;;               # macOS-specific
        ueberzugpp) echo "BINARY_INSTALL:ueberzugpp" ;;
        atuin) echo "BINARY_INSTALL:atuin" ;;
        carapace) echo "BINARY_INSTALL:carapace" ;;

        # Default
        *) echo "$generic" ;;
        esac
        ;;
    pacman)
        case "$generic" in
        # Build tools
        build-essential) echo "base-devel" ;;

        # Arch has MANY modern tools in official repos!
        fd | bat | eza | zoxide | starship | ripgrep | fzf) echo "$generic" ;;
        bottom | btop | procs | dust | duf | sd | tokei) echo "$generic" ;;
        git | curl | wget | stow | tmux | neovim | tree-sitter) echo "$generic" ;;
        jq | yq | htop | tree | direnv | fish | terraform) echo "$generic" ;;
        kubectl | helm | kubectx | stern) echo "$generic" ;;
        docker | podman | nmap | tcpdump | httpie | mtr) echo "$generic" ;;
        nodejs | npm | python | python-pip | go | rust) echo "$generic" ;;
        redis | graphviz | shellcheck | shfmt | github-cli) echo "$generic" ;;
        pandoc | just | lazydocker | trivy) echo "$generic" ;;

        # Arch-specific names
        golang) echo "go" ;;
        nodejs) echo "nodejs" ;;
        python@3.11) echo "python" ;;
        gh) echo "github-cli" ;;
        awscli) echo "aws-cli" ;;
        pipx) echo "python-pipx" ;;

        # Still need binary/AUR for some tools
        yazi | mise | kubie | terraform-docs | terragrunt)
            echo "BINARY_INSTALL:$generic"
            ;;
        uv | glow | gemini-cli | splash | onefetch)
            echo "BINARY_INSTALL:$generic"
            ;;
        granted | velero | argocd | flux | tflint | infracost)
            echo "BINARY_INSTALL:$generic"
            ;;
        minikube | k3d | kind | grpcurl | pulumi | act | task | jj)
            echo "BINARY_INSTALL:$generic"
            ;;
        bandwhich | doggo | fastfetch | syft | grype | tfsec)
            echo "BINARY_INSTALL:$generic"
            ;;
        checkov | semgrep | nuclei | sops | age | git-delta)
            echo "BINARY_INSTALL:$generic"
            ;;
        dive | ctop | gping | hyperfine | oha | glances | lnav)
            echo "BINARY_INSTALL:$generic"
            ;;
        curlie | xh | wrk | watchexec | commitizen)
            echo "BINARY_INSTALL:$generic"
            ;;
        crystal | bun | asdf | stylua | azure-cli | kubelogin | e1s)
            echo "BINARY_INSTALL:$generic"
            ;;

        # Arch package variations
        black) echo "python-black" ;;
        isort) echo "python-isort" ;;
        thefuck) echo "thefuck" ;;
        asciinema) echo "asciinema" ;;

        # Special cases — not system packages
        zsh-vi-mode) echo "" ;;          # Oh My Zsh plugin, not package
        tmux-fingers) echo "" ;;         # tmux plugin, not package
        choose | extract_url) echo "" ;; # macOS-only tools
        ollama) echo "" ;;               # Has its own installer (setup-selfhost-llm.sh)
        flamegraph) echo "" ;;           # Perl script, install via cargo/cpan
        colima) echo "" ;;               # macOS-specific
        ueberzugpp) echo "ueberzugpp" ;; # Available in Arch repos
        atuin) echo "BINARY_INSTALL:atuin" ;;
        carapace) echo "BINARY_INSTALL:carapace" ;;

        # Default
        *) echo "$generic" ;;
        esac
        ;;
    *)
        echo "$generic"
        ;;
    esac
}

log_verbose "Linux package manager module loaded"
