#!/usr/bin/env sh

# Get memory usage
MEMORY=$(memory_pressure | grep "System-wide memory free percentage" | awk '{print 100-$5}' | cut -d% -f1)

# Color based on usage
if [ $(echo "$MEMORY > 80" | bc) -eq 1 ]; then
  COLOR=0xfff7768e  # Red
elif [ $(echo "$MEMORY > 60" | bc) -eq 1 ]; then
  COLOR=0xffe0af68  # Yellow
else
  COLOR=0xff9ece6a  # Green
fi

sketchybar --set $NAME label="${MEMORY}%" label.color=$COLOR