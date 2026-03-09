#!/bin/bash
# Check if the cursor is currently over a window
if [[ $(hyprctl activewindow -j | jq '.address') == "null" ]]; then
    # No window is focused/under cursor; launch your menu
    sh ~/.config/rofi/quickactions.sh
fi

