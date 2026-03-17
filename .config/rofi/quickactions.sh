#!/usr/bin/env bash

# Options
run="Run"
clipboard="Clipboard"
emojiPicker="Emoji Picker"
iconPicker="Icon Picker"
colorPicker="Color Picker"
reloadWallpaper="Select wallpaper"
manageNetwork="Manage Network"
manageBluetooth="Manage Bluetooth"
power="Power Options"

launchRofi() {
    echo -e "$emojiPicker\n$iconPicker" | \
    rofi -dmenu -format s -theme launcher-style.rasi
}

case $(launchRofi) in
    $run)
        ~/.config/rofi/launcher.sh
    ;;

    $clipboard)
        clipvault list | rofi -theme ~/.config/rofi/launcher-style.rasi -dmenu -display-columns 2 | clipvault get | wl-copy
    ;;
    
	$emojiPicker)
		rofimoji \
			--action copy \
			--hidden-descriptions \
			--use-icons \
			--selector-args "-theme $HOME/.config/rofi/emoji-style.rasi"
	;;

	$iconPicker)
		rofimoji \
            --action copy \
            --hidden-descriptions \
            --use-icons \
			--files all \
            --selector-args "-theme $HOME/.config/rofi/emoji-style.rasi"
	;;

	$colorPicker)
	    hyprpicker -a
	;;

	$reloadWallpaper)
	    waypaper
    ;;

	$manageNetwork)
		# ronema
		kitty nmtui
	;;

	$manageBluetooth)
		rofi-bluetooth \
			-theme $HOME/.config/rofi/launcher-style.rasi
	;;

	$power)
		~/.config/rofi/powermenu.sh
	;;
esac
