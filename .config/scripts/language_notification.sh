#!/bin/sh
# Function to handle IPC events
handle() {
  case $1 in
    activelayout*) 
      layout=$(echo "$1" | cut -d',' -f2)
      swayosd-client --monitor "$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')" --custom-message "$layout" --custom-icon "preferences-desktop-locale"
      ;;
  esac
}

# Connect to Hyprland's event socket
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do handle "$line"; done
