# Pi-hole management wrapper
# Runs Pi-hole via Colima + Docker for local ad blocking
#
# Usage:
#   pihole start      - Start Pi-hole
#   pihole stop       - Stop Pi-hole
#   pihole status     - Show status
#   pihole dns-on     - Point macOS DNS to Pi-hole
#   pihole dns-off    - Restore Cloudflare DNS
#   pihole logs       - Tail logs
#   pihole update     - Pull latest image
#   pihole restart    - Restart container
#   pihole uninstall  - Remove everything

function pihole --description "Manage Pi-hole DNS ad blocker (Colima + Docker)"
    set -l dotfiles_root ~/dotfiles
    set -l pihole_script "$dotfiles_root/scripts/pihole/setup-pihole.sh"

    if not test -f "$pihole_script"
        echo "Pi-hole script not found at $pihole_script"
        return 1
    end

    if test (count $argv) -eq 0
        bash "$pihole_script" status
    else
        bash "$pihole_script" $argv
    end
end
