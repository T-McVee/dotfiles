#!/bin/bash

sketchybar --add item cpu right \
           --set cpu  update_freq=2 \
                      icon=􀧓  \
                      associated_display=1 \
                      script="$PLUGIN_DIR/cpu.sh"