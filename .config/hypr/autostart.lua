hl.on('hyprland.start', function ()
    hl.exec_cmd('dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP')
    hl.exec_cmd('systemctl --user start hyprland-session.target')
    
    -- Shell
    hl.exec_cmd('quickshell --config BoomShell')
    hl.exec_cmd('quickshell --config BoomDeskidgets')
        
    -- Wallpaper
    hl.exec_cmd('systemctl --user start skwd-daemon')

    -- Clipboard
    hl.exec_cmd('wl-paste --watch clipvault store')

    -- Gui sudo
    hl.exec_cmd('systemctl --user start hyprpolkitagent')

    -- Terminal with default programs open
    hl.exec_cmd('kitty --session ~/.config/kitty/dashboard.session')

    -- Launch Hyprland plugins
    hl.exec_cmd('hyprpm reload')

    -- Detect when laptop isn't charging and display notifications
    hl.exec_cmd('~/.config/scripts/battery_notification.sh')
end)
