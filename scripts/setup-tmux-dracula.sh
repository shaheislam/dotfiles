#!/usr/bin/env bash
# Setup script for customized Dracula tmux theme

set -e

echo "Setting up customized Dracula tmux theme..."

# Install Dracula theme if not present
if [ ! -d "$HOME/.tmux/plugins/dracula" ]; then
  echo "Installing Dracula tmux theme..."
  git clone https://github.com/dracula/tmux ~/.tmux/plugins/dracula
fi

# Apply RAM percentage patch
echo "Applying RAM percentage patch..."

RAM_SCRIPT="$HOME/.tmux/plugins/dracula/scripts/ram_info.sh"

# Check if already patched
if grep -q "# Calculate percentage" "$RAM_SCRIPT" 2>/dev/null; then
  echo "✓ RAM script already patched"
else
  echo "Patching RAM script for percentage display..."

  # Backup original
  cp "$RAM_SCRIPT" "$RAM_SCRIPT.bak.$(date +%Y%m%d)" 2>/dev/null || true

  # Create temporary file with patched content
  cat > /tmp/ram_info_patch.sh << 'EOF'
#!/usr/bin/env bash
# setting the locale, some users have issues with different locales, this forces the correct one
export LC_ALL=en_US.UTF-8

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $current_dir/utils.sh

get_ratio()
{
  case $(uname -s) in
    Linux)
      # Get used and total memory in MiB
      mem_info=$(free -m | grep '^Mem:')
      used_mem=$(echo $mem_info | awk '{print $3}')
      total_mem=$(echo $mem_info | awk '{print $2}')
      # Calculate percentage
      percentage=$((used_mem * 100 / total_mem))
      echo "${percentage}%"
      ;;

    Darwin)
      # Get used memory blocks with vm_stat, multiply by page size to get size in bytes, then convert to MiB
      used_mem=$(vm_stat | grep ' active\|wired\|compressor\|speculative' | sed 's/[^0-9]//g' | paste -sd ' ' - | awk -v pagesize=$(pagesize) '{printf "%d\n", ($1+$2+$3+$5) * pagesize / 1048576}')
      # Get total memory in MiB
      total_mem_bytes=$(sysctl -n hw.memsize)
      total_mem_mib=$((total_mem_bytes / 1048576))
      # Calculate percentage
      percentage=$((used_mem * 100 / total_mem_mib))
      echo "${percentage}%"
      ;;

    FreeBSD)
      # Looked at the code from neofetch
      hw_pagesize="$(sysctl -n hw.pagesize)"
      mem_inactive="$(($(sysctl -n vm.stats.vm.v_inactive_count) * hw_pagesize))"
      mem_unused="$(($(sysctl -n vm.stats.vm.v_free_count) * hw_pagesize))"
      mem_cache="$(($(sysctl -n vm.stats.vm.v_cache_count) * hw_pagesize))"

      free_mem=$(((mem_inactive + mem_unused + mem_cache) / 1024 / 1024))
      total_mem=$(($(sysctl -n hw.physmem) / 1024 / 1024))
      used_mem=$((total_mem - free_mem))
      # Calculate percentage
      percentage=$((used_mem * 100 / total_mem))
      echo "${percentage}%"
      ;;

    OpenBSD)
      # vmstat -s | grep "pages managed" | sed -ne 's/^ *\([0-9]*\).*$/\1/p'
      # Get used and total memory in MiB
      total_mem=$(($(sysctl -n hw.physmem) / 1024 / 1024))
      free_mem=$(($(vmstat -s | grep "pages free$" | sed -ne 's/^ *\([0-9]*\).*$/\1/p') * $(sysctl -n hw.pagesize) / 1024 / 1024))
      used_mem=$((total_mem - free_mem))
      # Calculate percentage
      percentage=$((used_mem * 100 / total_mem))
      echo "${percentage}%"
      ;;

    CYGWIN*|MINGW32*|MSYS*|MINGW*)
      # TODO - windows compatability
      ;;
  esac
}

main()
{
  ram_label=$(get_tmux_option "@dracula-ram-usage-label" "RAM")
  ram_ratio=$(get_ratio)
  echo "$ram_label $ram_ratio"
}

#run main driver
main
EOF

  # Replace the original script
  mv /tmp/ram_info_patch.sh "$RAM_SCRIPT"
  chmod +x "$RAM_SCRIPT"

  echo "✓ RAM script patched successfully"
fi

echo ""
echo "Dracula tmux theme setup complete!"
echo "The RAM display will now show as percentage only."
echo ""
echo "To apply this on other devices:"
echo "1. Pull your dotfiles repo"
echo "2. Run: ./scripts/setup-tmux-dracula.sh"
echo "3. Restart tmux"
