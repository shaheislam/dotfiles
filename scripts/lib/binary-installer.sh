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
    local arch_suffix=$(get_arch_suffix)

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
            local latest_tag=$(get_latest_release_tag "sharkdp/bat")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/sharkdp/bat/releases/download/${latest_tag}/bat-${latest_tag}-${arch_suffix}.tar.gz"
            ;;
        ripgrep)
            local latest_tag=$(get_latest_release_tag "BurntSushi/ripgrep")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/BurntSushi/ripgrep/releases/download/${latest_tag}/ripgrep-${latest_tag}-${arch_suffix}.tar.gz"
            ;;
        fd)
            local latest_tag=$(get_latest_release_tag "sharkdp/fd")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/sharkdp/fd/releases/download/${latest_tag}/fd-${latest_tag}-${arch_suffix}.tar.gz"
            ;;

        # Additional Modern CLI Tools
        bottom)
            local latest_tag=$(get_latest_release_tag "ClementTsang/bottom")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/ClementTsang/bottom/releases/download/${latest_tag}/bottom_${arch_suffix}.tar.gz"
            ;;
        btop)
            local latest_tag=$(get_latest_release_tag "aristocratos/btop")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/aristocratos/btop/releases/download/${latest_tag}/btop-${arch_suffix}.tbz"
            ;;
        procs)
            local latest_tag=$(get_latest_release_tag "dalance/procs")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/dalance/procs/releases/download/${latest_tag}/procs-${latest_tag}-${arch_suffix}.zip"
            ;;
        dust)
            local latest_tag=$(get_latest_release_tag "bootandy/dust")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/bootandy/dust/releases/download/${latest_tag}/dust-${latest_tag}-${arch_suffix}.tar.gz"
            ;;
        duf)
            local latest_tag=$(get_latest_release_tag "muesli/duf")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/muesli/duf/releases/download/${latest_tag}/duf_${latest_tag#v}_${os}_${arch_suffix}.tar.gz"
            ;;

        # Kubernetes Tools
        kubectl)
            local latest=$(curl -L -s https://dl.k8s.io/release/stable.txt)
            echo "https://dl.k8s.io/release/${latest}/bin/${os}/$(uname -m)/kubectl"
            ;;
        helm)
            local latest_tag=$(get_latest_release_tag "helm/helm")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://get.helm.sh/helm-${latest_tag}-${os}-$(uname -m).tar.gz"
            ;;
        kubectx)
            local latest_tag=$(get_latest_release_tag "ahmetb/kubectx")
            [[ -z "$latest_tag" ]] && return 1
            # kubectx package includes both kubectx and kubens commands
            echo "https://github.com/ahmetb/kubectx/releases/download/${latest_tag}/${tool}_${latest_tag}_${os}_$(uname -m).tar.gz"
            ;;

        # AWS Tools
        granted)
            local latest_tag=$(get_latest_release_tag "common-fate/granted")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/common-fate/granted/releases/download/${latest_tag}/granted_${latest_tag#v}_${os}_$(uname -m).tar.gz"
            ;;

        # Terraform Tools
        terraform-docs)
            local latest_tag=$(get_latest_release_tag "terraform-docs/terraform-docs")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/terraform-docs/terraform-docs/releases/download/${latest_tag}/terraform-docs-${latest_tag}-${os}-$(uname -m).tar.gz"
            ;;
        terragrunt)
            local latest_tag=$(get_latest_release_tag "gruntwork-io/terragrunt")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/gruntwork-io/terragrunt/releases/download/${latest_tag}/terragrunt_${os}_$(uname -m)"
            ;;
        tflint)
            local latest_tag=$(get_latest_release_tag "terraform-linters/tflint")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/terraform-linters/tflint/releases/download/${latest_tag}/tflint_${os}_$(uname -m).zip"
            ;;

        # Container Tools
        lazydocker)
            local latest_tag=$(get_latest_release_tag "jesseduffield/lazydocker")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/jesseduffield/lazydocker/releases/download/${latest_tag}/lazydocker_${latest_tag#v}_${os}_$(uname -m).tar.gz"
            ;;
        dive)
            local latest_tag=$(get_latest_release_tag "wagoodman/dive")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/wagoodman/dive/releases/download/${latest_tag}/dive_${latest_tag#v}_${os}_$(uname -m).tar.gz"
            ;;
        ctop)
            local latest_tag=$(get_latest_release_tag "bcicen/ctop")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/bcicen/ctop/releases/download/${latest_tag}/ctop-${latest_tag}-${os}-$(uname -m)"
            ;;

        # Security Tools
        trivy)
            local latest_tag=$(get_latest_release_tag "aquasecurity/trivy")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/aquasecurity/trivy/releases/download/${latest_tag}/trivy_${latest_tag#v}_${os}-64bit.tar.gz"
            ;;
        syft)
            local latest_tag=$(get_latest_release_tag "anchore/syft")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/anchore/syft/releases/download/${latest_tag}/syft_${latest_tag#v}_${os}_$(uname -m).tar.gz"
            ;;
        grype)
            local latest_tag=$(get_latest_release_tag "anchore/grype")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/anchore/grype/releases/download/${latest_tag}/grype_${latest_tag#v}_${os}_$(uname -m).tar.gz"
            ;;

        # Other Tools
        git-delta)
            local latest_tag=$(get_latest_release_tag "dandavison/delta")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/dandavison/delta/releases/download/${latest_tag}/delta-${latest_tag}-${arch_suffix}.tar.gz"
            ;;
        yazi)
            local latest_tag=$(get_latest_release_tag "sxyazi/yazi")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/sxyazi/yazi/releases/download/${latest_tag}/yazi-${arch_suffix}.zip"
            ;;
        atuin)
            local latest_tag=$(get_latest_release_tag "atuinsh/atuin")
            [[ -z "$latest_tag" ]] && return 1
            echo "https://github.com/atuinsh/atuin/releases/download/${latest_tag}/atuin-${latest_tag}-${arch_suffix}.tar.gz"
            ;;
        glow)
            local latest_tag=$(get_latest_release_tag "charmbracelet/glow")
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

    # Check if already installed
    if command_exists "$tool"; then
        log_verbose "$tool already installed"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install binary for $tool into $install_dir"
        return 0
    fi

    # Get download URL
    local url=$(get_binary_download_url "$tool")

    if [[ -z "$url" ]]; then
        log_verbose "No binary download available for $tool"
        return 1
    fi

    print_step "Installing $tool from binary..."

    # Create temp directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" RETURN

    # Download and extract
    if ! download_file "$url" "$temp_dir/archive.tar.gz"; then
        print_warning "Failed to download $tool"
        return 1
    fi

    # Extract
    mkdir -p "$temp_dir/extracted"
    if ! extract_archive "$temp_dir/archive.tar.gz" "$temp_dir/extracted"; then
        print_warning "Failed to extract $tool"
        return 1
    fi

    # Find and install binary
    local binary=$(find "$temp_dir/extracted" -type f -name "$tool" -perm +111 | head -1)

    if [[ -z "$binary" ]]; then
        # Try common patterns
        binary=$(find "$temp_dir/extracted" -type f -perm +111 | grep -E "/$tool$|/${tool}-[^/]+$" | head -1)
    fi

    if [[ -n "$binary" ]]; then
        mkdir -p "$install_dir"
        cp "$binary" "$install_dir/$tool"
        chmod +x "$install_dir/$tool"
        print_success "Installed: $tool"
        return 0
    else
        print_warning "Binary not found in archive for $tool"
        return 1
    fi
}

install_binaries_from_profile() {
    local profile=$1

    # All tools supported by get_binary_download_url()
    local binaries=(
        # Original modern CLI tools
        "starship" "eza" "zoxide" "bat" "ripgrep" "fd"

        # Additional modern CLI tools
        "bottom" "btop" "procs" "dust" "duf"

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

        # Other tools
        "git-delta" "yazi" "atuin" "glow"
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
