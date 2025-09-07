#!/bin/bash

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

source "$CONFIG_DIR/colors.sh" # Loads all defined colors

if [ $SELECTED = true ]; then
  sketchybar --set $NAME background.drawing=on \
                         label.color=$ACCENT_COLOR \
                         icon.color=$ACCENT_COLOR \
                         background.color=$SECONDARY_COLOR

else
  sketchybar --set $NAME background.drawing=off \
                         label.color=$WHITE \
                         icon.color=$WHITE
fi