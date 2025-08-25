#!/usr/bin/env bash
# Get CPU percentage and format as 2-digit number without %
cpu=$(/Users/shaheislam/.tmux/plugins/tmux-cpu/scripts/cpu_percentage.sh | sed 's/%//')
printf "%02.0f" "$cpu"