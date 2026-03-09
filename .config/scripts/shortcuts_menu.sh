#!/bin/bash

# Configuration file path
CONFIG_FILE="$HOME/.config/hypr/keybinds.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    rofi -e "Error: Hyprland config file not found at $CONFIG_FILE"
    exit 1
fi

awk '
# Match lines starting with bind or bindd
/^bind/ {
    # Store the original line to check for comments later (for standard binds)
    original_line = $0;
    
    # Check if this is a "bindd" (bind with description) or standard "bind"
    is_bindd = 0;
    if ($0 ~ /^bindd/) {
        is_bindd = 1;
    }

    # Replace $mainMod with SUPER for display
    gsub(/\$mainMod/, "SUPER", $0);

    # Clean up the "bind=" or "bindd=" prefix so we just have comma-separated values
    sub(/^bindd? *= */, "", $0);

    # Split the line by commas
    split($0, parts, ",");

    # 1. Extract Modifier
    mod = parts[1];
    gsub(/ /, "", mod); # Remove spaces

    # 2. Extract Key
    key = parts[2];
    gsub(/ /, "", key);

    # 3. Extract Description
    desc = "";
    
    if (is_bindd == 1) {
        # SYNTAX: bindd = MOD, KEY, DESCRIPTION, DISPATCHER, ARG
        # The description is explicitly the 3rd argument
        desc = parts[3];
        # Trim leading/trailing whitespace
        gsub(/^ +| +$/, "", desc);
    } else {
        # SYNTAX: bind = MOD, KEY, DISPATCHER, ARG
        # Fallback logic for standard binds:
        
        # Check if there is a comment (#) in the original line
        if (match(original_line, /#/)) {
            desc = substr(original_line, RSTART + 1);
            gsub(/^ +| +$/, "", desc); # Trim
        } else {
            # If no comment, just show the command (fields 3 and onwards)
            for (i = 3; i <= length(parts); i++) {
                # Clean up arg part
                clean_part = parts[i];
                gsub(/^ +| +$/, "", clean_part);
                
                # Strip inline comments if they got caught here
                sub(/#.*/, "", clean_part); 

                if (desc == "") {
                    desc = clean_part;
                } else {
                    desc = desc " " clean_part;
                }
            }
        }
    }

    # Output Format: [MOD+KEY] - Description
    if (mod == "") {
        printf "[%s] - %s\n", key, desc;
    } else {
        printf "[%s+%s] - %s\n", mod, key, desc;
    }

}' "$CONFIG_FILE" | \
# Pipe into Rofi
rofi \
    -dmenu \
    -i \
    -p "Shortcuts" \
    -theme $HOME/.config/rofi/launcher-style.rasi
