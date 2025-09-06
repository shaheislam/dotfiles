#!/usr/bin/env sh

# Get CPU usage percentage
CPU=$(top -l 2 -n 0 -s 1 | grep "CPU usage" | tail -1 | awk '{print $3}' | cut -d% -f1)

# Color based on usage
if [ $(echo "$CPU > 80" | bc) -eq 1 ]; then
  COLOR=0xfff7768e  # Red
elif [ $(echo "$CPU > 50" | bc) -eq 1 ]; then
  COLOR=0xffe0af68  # Yellow  
else
  COLOR=0xff9ece6a  # Green
fi

sketchybar --set $NAME label="${CPU}%" label.color=$COLOR