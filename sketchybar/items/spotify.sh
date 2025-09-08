#!/bin/bash

source "$CONFIG_DIR/colors.sh" # Loads all defined colors

SPOTIFY_EVENT="com.spotify.client.PlaybackStateChanged"
POPUP_SCRIPT="sketchybar -m --set \$NAME popup.drawing=toggle"

sketchybar --add       event           spotify_change $SPOTIFY_EVENT      \
           --add       item            spotify.name e             \
           --set       spotify.name    click_script="$POPUP_SCRIPT"       \
                                       background.color=$BAR_COLOR_TRANSPARENT \
                                       label.padding_left=10 \
                                       label.padding_right=10 \
                                       popup.horizontal=on                \
                                       popup.align=center                 \
                                       popup.background.border_width=2 \
                                       popup.background.corner_radius=5 \
                                       popup.background.color=$SECONDARY_COLOR \
                                       popup.blur_radius=30 \
                                       icon.drawing=off                   \
                                                                          \
           --add       item            spotify.back popup.spotify.name    \
           --set       spotify.back    icon=􀊎                             \
                                       icon.padding_left=5                \
                                       icon.padding_right=5               \
                                       script="$PLUGIN_DIR/spotify.sh"    \
                                       label.drawing=off                  \
           --subscribe spotify.back    mouse.clicked                      \
                                                                          \
           --add       item            spotify.play popup.spotify.name    \
           --set       spotify.play    icon=􀊔                             \
                                       icon.padding_left=5                \
                                       icon.padding_right=5               \
                                       updates=on                         \
                                       label.drawing=off                  \
                                       script="$PLUGIN_DIR/spotify.sh"    \
           --subscribe spotify.play    mouse.clicked spotify_change       \
                                                                          \
           --add       item            spotify.next popup.spotify.name    \
           --set       spotify.next    icon=􀊐                             \
                                       icon.padding_left=5                \
                                       icon.padding_right=10              \
                                       label.drawing=off                  \
                                       script="$PLUGIN_DIR/spotify.sh"    \
           --subscribe spotify.next    mouse.clicked                      \
                                                                          \
           --add       item            spotify.shuffle popup.spotify.name \
           --set       spotify.shuffle icon=􀊝                             \
                                       icon.highlight_color=0xff1DB954    \
                                       icon.padding_left=5                \
                                       icon.padding_right=5               \
                                       label.drawing=off                  \
                                       script="$PLUGIN_DIR/spotify.sh"    \
           --subscribe spotify.shuffle mouse.clicked                      \
                                                                          \
           --add       item            spotify.repeat popup.spotify.name  \
           --set       spotify.repeat  icon=􀊞                             \
                                       icon.highlight_color=0xff1DB954    \
                                       icon.padding_left=5                \
                                       icon.padding_right=5               \
                                       label.drawing=off                  \
                                       script="$PLUGIN_DIR/spotify.sh"    \
           --subscribe spotify.repeat  mouse.clicked