local function setupSpecialWorkspace(name, bind, cmd)
    local special = "special:" .. name

    hl.workspace_rule({
        workspace = special,
        persistent = true,
        on_created_empty = cmd,
    })

    hl.bind(bind, function()
        local windows = hl.get_workspace_windows(special)

        if #windows == 0 then
            hl.exec_cmd(string.format("[workspace %s silent] %s", special, cmd))
        end

        -- Always toggle visibility
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
    end)

    -- Autostart
    -- hl.exec_cmd(string.format("[workspace %s silent] %s", special, cmd))
end

setupSpecialWorkspace("Telegram", "SUPER + T", "materialgram")
setupSpecialWorkspace("VPN", "SUPER + K", "flclashx")
setupSpecialWorkspace("Music", "SUPER + M", "floorp --name YTMusic -P \"YTMusic\" --start-ssb \"{96a4ed3f-4aea-4f80-907d-a47636f3e4f3}\"")