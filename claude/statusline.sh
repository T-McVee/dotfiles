#!/bin/bash

read -r data

model=$(echo "$data" | jq -r '.model.display_name // "?"')
pct=$(echo "$data" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

bar_width=20
filled=$((pct * bar_width / 100))
empty=$((bar_width - filled))

if [ "$pct" -ge 80 ]; then
  color="\033[31m"
elif [ "$pct" -ge 50 ]; then
  color="\033[33m"
else
  color="\033[32m"
fi
reset="\033[0m"

bar="${color}$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))${reset}"

echo -e "$model  $bar ${pct}%"
