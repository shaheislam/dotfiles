#!/usr/bin/env bash
# aimux queue - ticket queue management (stub for MVP)

case "${1:-help}" in
add)
    shift
    echo "Queue add: not yet implemented in aimux MVP"
    echo "Use: gwt-queue add (from dotfiles Fish functions)"
    ;;
list | ls)
    echo "Queue list: not yet implemented in aimux MVP"
    echo "Use: gwt-queue list (from dotfiles Fish functions)"
    ;;
start)
    echo "Queue start: not yet implemented in aimux MVP"
    ;;
stop)
    echo "Queue stop: not yet implemented in aimux MVP"
    ;;
status)
    echo "Queue status: not yet implemented in aimux MVP"
    ;;
-h | --help | help | *)
    cat <<'HELP'
Usage: aimux queue <subcommand>

Manage ticket execution queue (MVP: stub — full implementation coming)

Subcommands:
  add <ticket> [prompt]   Add ticket to queue
  list                    Show queued tickets
  start                   Start queue daemon
  stop                    Stop queue daemon
  status                  Show queue status
  help                    Show this help

For now, use gwt-queue from dotfiles Fish functions for full functionality.
HELP
    ;;
esac
