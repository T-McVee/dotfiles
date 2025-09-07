#!/bin/bash

source "$CONFIG_DIR/colors.sh" # Loads all defined colors

# Apple logo demo
sketchybar --add item apple.logo left \
           --set apple.logo icon=􀣺  \
                 icon.font="SF Pro:Black:16.0" \
                 label.drawing=off \
                 click_script="sketchybar -m --set \$NAME popup.drawing=toggle" \
                 popup.background.border_width=2 \
                 popup.background.corner_radius=5 \
                 popup.background.color=$SECONDARY_COLOR \
                 popup.blur_radius=30 \
                 popup.background.border_color=$BAR_COLOR \
           --add item apple.preferences popup.apple.logo \
           --set apple.preferences icon=􀺽 \
                 label="Preferences" \
                 label.color=$BLACK \
                 icon.color=$BLACK \
                 click_script="open -a 'System Preferences'; \
                               sketchybar -m --set apple.logo popup.drawing=off" \
           --add item apple.lock popup.apple.logo \
           --set apple.lock icon=􀒳 \
                            label="Lock Screen" \
                            label.color=$BLACK \
                            icon.color=$BLACK \
                            click_script="pmset displaysleepnow;                           
                                          sketchybar -m --set apple.logo popup.drawing=off"