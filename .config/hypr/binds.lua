local mainMod = "SUPER"





-- ##########################
-- ########## Apps ##########
-- ##########################

-- Terminal
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. ' + Return', hl.dsp.exec_cmd('kitty --session ~/.config/kitty/dashboard.session'))

-- Browser
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd('floorp'))

-- File manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd('nemo'))





-- ##########################
-- ######### Modals #########
-- ##########################

-- Drun
hl.bind(mainMod .. " + Super_L", hl.dsp.exec_cmd("~/.config/rofi/launcher.sh"))

-- Clipboard manager
hl.bind(mainMod .. " + PERIOD", hl.dsp.exec_cmd("clipvault list | rofi -theme ~/.config/rofi/launcher-style.rasi -dmenu -display-columns 2 | clipvault get | wl-copy"))

-- Password manager
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd('rofi-rbw --action copy --use-notify-send --selector rofi --selector-args="-theme ~/.config/rofi/launcher-style.rasi"'))

-- Power options
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("wlogout"))

-- Wallpaper picker
hl.bind(mainMod .. ' + W', hl.dsp.exec_cmd('skwd wall toggle'))

-- Screenshot
hl.bind(mainMod .. ' + Print', hl.dsp.exec_cmd('quickshell -c HyprQuickFrame -n'))

-- Screen recording
hl.bind(mainMod .. ' + SHIFT + R', hl.dsp.exec_cmd('flatpak run com.dec05eba.gpu_screen_recorder'))

-- Window info
hl.bind(mainMod .. ' + SHIFT + W', hl.dsp.exec_cmd('rofi -e "$(hyprctl activewindow)"'))

hl.bind(mainMod .. ' + CTRL + W', hl.dsp.exec_cmd('echo toggle > /tmp/buff_toggle_wifi'))
hl.bind(mainMod .. ' + CTRL + B', hl.dsp.exec_cmd('echo toggle > /tmp/buff_toggle_bluetooth'))
hl.bind(mainMod .. ' + CTRL + S', hl.dsp.exec_cmd('echo toggle > /tmp/buff_toggle_start'))
hl.bind(mainMod .. ' + CTRL + C', hl.dsp.exec_cmd('echo toggle > /tmp/buff_toggle_calendar'))





-- ##########################
-- #### Window managment ####
-- ##########################

-- Close window
hl.bind(mainMod .. " + C", hl.dsp.window.close())

-- Force close window
hl.bind(mainMod .. ' + SHIFT + C', hl.dsp.window.kill())

-- Toggle floating window
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Toggle fullscreen
hl.bind(mainMod .. ' + F', hl.dsp.window.fullscreen({ action = 'toggle' }))

-- Swap windows vertically/horizontally (dwindle only)
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Move window with mainMod + arrow keys
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i, on_current_monitor = true }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Media playback controls
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })