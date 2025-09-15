#!/bin/bash

sketchybar --add item calendar right \
           --set calendar  \
                 associated_display=1 \
                 update_freq=30 \
                 script="$PLUGIN_DIR/calendar.sh"