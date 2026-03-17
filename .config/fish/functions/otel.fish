# OpenTelemetry LGTM stack management wrapper
# Runs grafana/otel-lgtm via Colima + Docker for local observability
#
# Usage:
#   otel start    - Start OTEL LGTM stack
#   otel stop     - Stop stack
#   otel status   - Show status
#   otel open     - Open Grafana in browser
#   otel doctor   - Verify OTEL env + container health
#   otel logs     - Tail container logs
#   otel restart  - Restart container
#   otel update   - Pull latest image
#   otel uninstall - Remove everything

function otel --description "Manage OpenTelemetry LGTM observability stack (Colima + Docker)"
    set -l dotfiles_root ~/dotfiles
    set -l otel_script "$dotfiles_root/scripts/otel/setup-otel.sh"

    if not test -f "$otel_script"
        echo "OTEL script not found at $otel_script"
        return 1
    end

    if test (count $argv) -eq 0
        bash "$otel_script" status
    else
        bash "$otel_script" $argv
    end
end
