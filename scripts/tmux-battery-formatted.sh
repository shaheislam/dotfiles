#!/usr/bin/env bash
# Get battery percentage and format without %
battery=$(/Users/shaheislam/.tmux/plugins/tmux-battery/scripts/battery_percentage.sh | sed 's/%//')
echo "$battery"