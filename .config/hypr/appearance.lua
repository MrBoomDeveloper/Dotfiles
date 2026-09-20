hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 2,
        border_size = 1,
        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle",

		col = {
            active_border = "#f7b5f2ff",
            inactive_border = "#170a16cc",
        }
    },

    decoration = {
        rounding = 10,
        rounding_power = 5,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "#ee1a1a1a",
        },

        blur = {
            enabled = false
        }
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        close_special_on_empty = false
    },

    ecosystem = {
        no_donation_nag = true
    }
})
