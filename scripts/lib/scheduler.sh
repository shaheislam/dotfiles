#!/usr/bin/env bash

# Cross-OS scheduler helpers for dotfiles-managed background services.
# macOS uses existing LaunchAgent templates; Linux/WSL prefer systemd --user and
# fall back to a user crontab when systemd is unavailable.

scheduler_has_systemd_user() {
    command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
}

scheduler_user_dir() {
    printf '%s/.config/systemd/user' "$HOME"
}

scheduler_path() {
    printf '%s/scripts/bin:%s/.bun/bin:%s/.local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' \
        "$DOTFILES_ROOT" "$HOME" "$HOME"
}

scheduler_write_systemd_service() {
    local label="$1"
    local command="$2"
    local working_dir="$3"
    local stdout_path="$4"
    local stderr_path="$5"
    local keepalive="$6"
    local unit_dir service_path restart_policy

    unit_dir="$(scheduler_user_dir)"
    service_path="$unit_dir/$label.service"
    restart_policy="no"
    [[ "$keepalive" == "true" ]] && restart_policy="always"

    mkdir -p "$unit_dir" "$(dirname "$stdout_path")" "$(dirname "$stderr_path")"
    cat >"$service_path" <<EOF
[Unit]
Description=$label

[Service]
Type=simple
WorkingDirectory=$working_dir
ExecStart=$command
Restart=$restart_policy
RestartSec=30
Environment=HOME=$HOME
Environment=DOTFILES_ROOT=$DOTFILES_ROOT
Environment=PATH=$(scheduler_path)
StandardOutput=append:$stdout_path
StandardError=append:$stderr_path

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now "$label.service"
}

scheduler_write_systemd_timer() {
    local label="$1"
    local command="$2"
    local working_dir="$3"
    local stdout_path="$4"
    local stderr_path="$5"
    local on_calendar="$6"
    local unit_dir service_path timer_path

    unit_dir="$(scheduler_user_dir)"
    service_path="$unit_dir/$label.service"
    timer_path="$unit_dir/$label.timer"

    mkdir -p "$unit_dir" "$(dirname "$stdout_path")" "$(dirname "$stderr_path")"
    cat >"$service_path" <<EOF
[Unit]
Description=$label

[Service]
Type=oneshot
WorkingDirectory=$working_dir
ExecStart=$command
Environment=HOME=$HOME
Environment=DOTFILES_ROOT=$DOTFILES_ROOT
Environment=PATH=$(scheduler_path)
StandardOutput=append:$stdout_path
StandardError=append:$stderr_path
EOF

    cat >"$timer_path" <<EOF
[Unit]
Description=$label timer

[Timer]
OnCalendar=$on_calendar
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now "$label.timer"
}

scheduler_install_cron() {
    local label="$1"
    local command="$2"
    local working_dir="$3"
    local stdout_path="$4"
    local stderr_path="$5"
    local schedule="$6"
    local escaped_line tmp_cron

    if ! command -v crontab >/dev/null 2>&1; then
        print_warning "No systemd --user or crontab available for $label"
        return 1
    fi

    mkdir -p "$(dirname "$stdout_path")" "$(dirname "$stderr_path")"
    escaped_line="$schedule cd '$working_dir' && HOME='$HOME' DOTFILES_ROOT='$DOTFILES_ROOT' PATH='$(scheduler_path)' $command >>'$stdout_path' 2>>'$stderr_path' # dotfiles:$label"
    tmp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "# dotfiles:$label" >"$tmp_cron" || true
    printf '%s\n' "$escaped_line" >>"$tmp_cron"
    crontab "$tmp_cron"
    rm -f "$tmp_cron"
}

scheduler_register_service() {
    local label="$1"
    local command="$2"
    local working_dir="$3"
    local stdout_path="$4"
    local stderr_path="$5"
    local started_message="$6"
    local skipped_message="$7"
    local already_message="$8"
    local keepalive="${9:-true}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install scheduled service $label"
        return 0
    fi

    if [[ "${DETECTED_OS:-}" == "macos" ]]; then
        install_launchagent_template "$label" "$started_message" "$skipped_message" "$already_message"
        return $?
    fi

    if scheduler_has_systemd_user; then
        if scheduler_write_systemd_service "$label" "$command" "$working_dir" "$stdout_path" "$stderr_path" "$keepalive"; then
            print_success "$started_message"
        else
            log_verbose "$skipped_message"
        fi
    else
        if scheduler_install_cron "$label" "$command" "$working_dir" "$stdout_path" "$stderr_path" "@reboot"; then
            print_success "$started_message"
        else
            log_verbose "$skipped_message"
        fi
    fi
}

scheduler_register_timer() {
    local label="$1"
    local command="$2"
    local working_dir="$3"
    local stdout_path="$4"
    local stderr_path="$5"
    local on_calendar="$6"
    local cron_schedule="$7"
    local started_message="$8"
    local skipped_message="$9"
    local already_message="${10:-$label already loaded}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install scheduled timer $label"
        return 0
    fi

    if [[ "${DETECTED_OS:-}" == "macos" ]]; then
        install_launchagent_template "$label" "$started_message" "$skipped_message" "$already_message"
        return $?
    fi

    if scheduler_has_systemd_user; then
        if scheduler_write_systemd_timer "$label" "$command" "$working_dir" "$stdout_path" "$stderr_path" "$on_calendar"; then
            print_success "$started_message"
        else
            log_verbose "$skipped_message"
        fi
    else
        if scheduler_install_cron "$label" "$command" "$working_dir" "$stdout_path" "$stderr_path" "$cron_schedule"; then
            print_success "$started_message"
        else
            log_verbose "$skipped_message"
        fi
    fi
}
