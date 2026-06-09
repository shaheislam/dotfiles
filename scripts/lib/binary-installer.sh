#!/usr/bin/env bash

# binary-installer.sh - Cross-platform binary installation
# Downloads and installs pre-compiled binaries for macOS and Linux

# shellcheck source=./common.sh
source "$SCRIPT_DIR/lib/common.sh"

# ============================================================================
# Binary URL Mapping
# ============================================================================

get_latest_release_tag() {
    local repo=$1
    local tag

    # Try GitHub API first
    tag=$(curl -sL "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    # If API fails, try scraping releases page
    if [[ -z "$tag" ]]; then
        log_verbose "GitHub API failed, trying releases page"
        tag=$(curl -sL "https://github.com/$repo/releases/latest" | grep -oE 'href="/[^/]+/[^/]+/releases/tag/[^"]+' | head -1 | sed 's/.*\///')
    fi

    if [[ -z "$tag" ]]; then
        print_warning "Failed to get latest release tag for $repo"
        return 1
    fi

    echo "$tag"
}

get_binary_download_url() {
    local tool=$1
    local os=${DETECTED_OS:-$(detect_os)}
    local arch_suffix
    local latest_tag
    local latest

    arch_suffix=$(get_arch_suffix)

    case "$tool" in
    # Original tools
    starship)
        echo "https://github.com/starship/starship/releases/latest/download/starship-${arch_suffix}.tar.gz"
        ;;
    eza)
        if [[ "$os" == "macos" ]]; then
            echo "" # Use Homebrew on macOS
        else
            echo "https://github.com/eza-community/eza/releases/latest/download/eza_${arch_suffix}.tar.gz"
        fi
        ;;
    zoxide)
        echo "https://github.com/ajeetdsouza/zoxide/releases/latest/download/zoxide-${arch_suffix}.tar.gz"
        ;;
    bat)
        latest_tag=$(get_latest_release_tag "sharkdp/bat") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/sharkdp/bat/releases/download/${latest_tag}/bat-${latest_tag}-${arch_suffix}.tar.gz"
        ;;
    ripgrep)
        latest_tag=$(get_latest_release_tag "BurntSushi/ripgrep") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/BurntSushi/ripgrep/releases/download/${latest_tag}/ripgrep-${latest_tag}-${arch_suffix}.tar.gz"
        ;;
    ast-grep)
        latest_tag=$(get_latest_release_tag "ast-grep/ast-grep") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/ast-grep/ast-grep/releases/download/${latest_tag}/app-${arch_suffix}.zip"
        ;;
    fd)
        latest_tag=$(get_latest_release_tag "sharkdp/fd") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/sharkdp/fd/releases/download/${latest_tag}/fd-${latest_tag}-${arch_suffix}.tar.gz"
        ;;

    # Additional Modern CLI Tools
    bottom)
        latest_tag=$(get_latest_release_tag "ClementTsang/bottom") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/ClementTsang/bottom/releases/download/${latest_tag}/bottom_${arch_suffix}.tar.gz"
        ;;
    btop)
        latest_tag=$(get_latest_release_tag "aristocratos/btop") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/aristocratos/btop/releases/download/${latest_tag}/btop-${arch_suffix}.tbz"
        ;;
    procs)
        latest_tag=$(get_latest_release_tag "dalance/procs") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/dalance/procs/releases/download/${latest_tag}/procs-${latest_tag}-${arch_suffix}.zip"
        ;;
    dust)
        latest_tag=$(get_latest_release_tag "bootandy/dust") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/bootandy/dust/releases/download/${latest_tag}/dust-${latest_tag}-${arch_suffix}.tar.gz"
        ;;
    duf)
        latest_tag=$(get_latest_release_tag "muesli/duf") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/muesli/duf/releases/download/${latest_tag}/duf_${latest_tag#v}_${os}_${arch_suffix}.tar.gz"
        ;;

    # Kubernetes Tools
    kubectl)
        latest=$(curl -L -s https://dl.k8s.io/release/stable.txt) || return 1
        echo "https://dl.k8s.io/release/${latest}/bin/${os}/$(uname -m)/kubectl"
        ;;
    helm)
        latest_tag=$(get_latest_release_tag "helm/helm") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://get.helm.sh/helm-${latest_tag}-${os}-$(uname -m).tar.gz"
        ;;
    kubectx)
        latest_tag=$(get_latest_release_tag "ahmetb/kubectx") || return 1
        [[ -z "$latest_tag" ]] && return 1
        # kubectx package includes both kubectx and kubens commands
        echo "https://github.com/ahmetb/kubectx/releases/download/${latest_tag}/${tool}_${latest_tag}_${os}_$(uname -m).tar.gz"
        ;;

    # AWS Tools
    granted)
        latest_tag=$(get_latest_release_tag "common-fate/granted") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/common-fate/granted/releases/download/${latest_tag}/granted_${latest_tag#v}_${os}_$(uname -m).tar.gz"
        ;;

    # Terraform Tools
    terraform-docs)
        latest_tag=$(get_latest_release_tag "terraform-docs/terraform-docs") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/terraform-docs/terraform-docs/releases/download/${latest_tag}/terraform-docs-${latest_tag}-${os}-$(uname -m).tar.gz"
        ;;
    terragrunt)
        latest_tag=$(get_latest_release_tag "gruntwork-io/terragrunt") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/gruntwork-io/terragrunt/releases/download/${latest_tag}/terragrunt_${os}_$(uname -m)"
        ;;
    tflint)
        latest_tag=$(get_latest_release_tag "terraform-linters/tflint") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/terraform-linters/tflint/releases/download/${latest_tag}/tflint_${os}_$(uname -m).zip"
        ;;

    # Container Tools
    lazydocker)
        latest_tag=$(get_latest_release_tag "jesseduffield/lazydocker") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/jesseduffield/lazydocker/releases/download/${latest_tag}/lazydocker_${latest_tag#v}_${os}_$(uname -m).tar.gz"
        ;;
    dive)
        latest_tag=$(get_latest_release_tag "wagoodman/dive") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/wagoodman/dive/releases/download/${latest_tag}/dive_${latest_tag#v}_${os}_$(uname -m).tar.gz"
        ;;
    ctop)
        latest_tag=$(get_latest_release_tag "bcicen/ctop") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/bcicen/ctop/releases/download/${latest_tag}/ctop-${latest_tag}-${os}-$(uname -m)"
        ;;

    # Security Tools
    trivy)
        latest_tag=$(get_latest_release_tag "aquasecurity/trivy") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/aquasecurity/trivy/releases/download/${latest_tag}/trivy_${latest_tag#v}_${os}-64bit.tar.gz"
        ;;
    syft)
        latest_tag=$(get_latest_release_tag "anchore/syft") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/anchore/syft/releases/download/${latest_tag}/syft_${latest_tag#v}_${os}_$(uname -m).tar.gz"
        ;;
    grype)
        latest_tag=$(get_latest_release_tag "anchore/grype") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/anchore/grype/releases/download/${latest_tag}/grype_${latest_tag#v}_${os}_$(uname -m).tar.gz"
        ;;

    # Other Tools
    git-delta)
        latest_tag=$(get_latest_release_tag "dandavison/delta") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/dandavison/delta/releases/download/${latest_tag}/delta-${latest_tag}-${arch_suffix}.tar.gz"
        ;;
    yazi)
        latest_tag=$(get_latest_release_tag "sxyazi/yazi") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/sxyazi/yazi/releases/download/${latest_tag}/yazi-${arch_suffix}.zip"
        ;;
    atuin)
        latest_tag=$(get_latest_release_tag "atuinsh/atuin") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/atuinsh/atuin/releases/download/${latest_tag}/atuin-${latest_tag}-${arch_suffix}.tar.gz"
        ;;
    glow)
        latest_tag=$(get_latest_release_tag "charmbracelet/glow") || return 1
        [[ -z "$latest_tag" ]] && return 1
        echo "https://github.com/charmbracelet/glow/releases/download/${latest_tag}/glow_${os}_$(uname -m).tar.gz"
        ;;

    *)
        echo ""
        ;;
    esac
}

# ============================================================================
# Binary Installation
# ============================================================================

install_binary() {
    local tool=$1
    local install_dir="${2:-$HOME/.local/bin}"
    local executable=$tool

    case "$tool" in
    ast-grep) executable="sg" ;;
    esac

    # Check if already installed
    if command_exists "$executable"; then
        log_verbose "$executable already installed"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install binary for $tool into $install_dir"
        return 0
    fi

    # Get download URL
    local url
    url=$(get_binary_download_url "$tool")

    if [[ -z "$url" ]]; then
        log_verbose "No binary download available for $tool"
        return 1
    fi

    print_step "Installing $tool from binary..."

    # Create temp directory
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' RETURN

    local archive="$temp_dir/archive.tar.gz"
    case "$url" in
    *.zip) archive="$temp_dir/archive.zip" ;;
    *.tar.bz2 | *.tbz2) archive="$temp_dir/archive.tar.bz2" ;;
    *.tar.xz | *.txz) archive="$temp_dir/archive.tar.xz" ;;
    esac

    # Download and extract
    if ! download_file "$url" "$archive"; then
        print_warning "Failed to download $tool"
        return 1
    fi

    # Extract
    mkdir -p "$temp_dir/extracted"
    if ! extract_archive "$archive" "$temp_dir/extracted"; then
        print_warning "Failed to extract $tool"
        return 1
    fi

    # Find and install binary
    local binary
    binary=$(find "$temp_dir/extracted" -type f -name "$executable" \( -perm -u+x -o -perm -g+x -o -perm -o+x \) | head -1)

    if [[ -z "$binary" ]]; then
        # Try common patterns
        binary=$(find "$temp_dir/extracted" -type f \( -perm -u+x -o -perm -g+x -o -perm -o+x \) | grep -E "/$executable$|/${executable}-[^/]+$" | head -1)
    fi

    if [[ -n "$binary" ]]; then
        mkdir -p "$install_dir"
        cp "$binary" "$install_dir/$executable"
        chmod +x "$install_dir/$executable"
        print_success "Installed: $executable"
        return 0
    else
        print_warning "Binary not found in archive for $tool ($executable)"
        return 1
    fi
}

install_binaries_from_profile() {
    local profile=$1

    # All tools supported by get_binary_download_url()
    local binaries=(
        # Original modern CLI tools (ripgrep→rg and fd are in Brewfile)
        "starship" "eza" "zoxide" "bat" "ast-grep"

        # Additional modern CLI tools (bottom→btm is in Brewfile)
        "btop" "procs" "dust" "duf"

        # Kubernetes tools
        "kubectl" "helm" "kubectx"

        # AWS tools
        "granted"

        # Terraform tools
        "terraform-docs" "terragrunt" "tflint"

        # Container tools
        "lazydocker" "dive" "ctop"

        # Security tools
        "trivy" "syft" "grype"

        # Other tools (git-delta→delta and atuin are in Brewfile; glow moved to Brewfile)
        "yazi"
    )

    for binary in "${binaries[@]}"; do
        # Check if enabled in profile
        if [[ $(get_package_list_from_profile "$profile" "cli_tools") =~ $binary ]]; then
            if ! install_binary "$binary"; then
                print_warning "Binary installation failed for $binary"
                log_verbose "Falling back to package manager for $binary"
                # Fallback to package manager
                if command -v pm_install >/dev/null 2>&1; then
                    pm_install "$binary" || log_verbose "Package manager fallback also failed for $binary"
                fi
            fi
        fi
    done
}

log_verbose "Binary installer module loaded"
