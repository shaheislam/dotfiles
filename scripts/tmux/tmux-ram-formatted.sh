#!/usr/bin/env bash
# Get RAM percentage and format as 2-digit number without %
ram=$(~/.tmux/plugins/tmux-cpu/scripts/ram_percentage.sh | sed 's/%//')
printf "%02.0f" "$ram"