-- configs/appearance.lua
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        gaps_workspaces = 50,
        border_size = 2,
        allow_tearing = false,
        no_focus_fallback = true,
        col = {
            active_border = { colors = {Colors.primary}, angle = 45 },
            inactive_border = { colors = {Colors.surface_container}, angle = 45 },
        },
        resize_on_border = true,
        resize_corner = 3,
        layout = "dwindle",
    },
    cursor = {
        zoom_factor = 1,
        zoom_rigid = false,
        hotspot_padding = 1,
        hide_on_key_press = true,
        no_hardware_cursors = true,
        enable_hyprcursor = true,
        no_warps = false,
        persistent_warps = false,
        warp_on_change_workspace = 1,
        inactive_timeout = 7
    },
    render = {
        direct_scanout = 0,
    },
    xwayland = {
        force_zero_scaling = true,
    },
})

hl.config({
    group = {
        col = {
            border_active = { colors = {Colors.primary, Colors.tertiary}, angle = 45 },
            border_inactive = { colors = {Colors.on_secondary, Colors.surface_container}, angle = 45 },
            --border_locked_active = 1,
            --border_locked_inactive = 1,
        },
        groupbar = {
            font_size = 12,
            font_family = "monospace",
            font_weight_active = "ultraheavy",
            font_weight_inactive = "normal",
            indicator_height = 0,
            indicator_gap = 5,
            height = 22,
            gaps_in = 5,
            gaps_out = 0,
            text_color = Colors.on_primary,
            text_color_inactive = Colors.surface,
            col = {
                active = Colors.primary,
                inactive = Colors.on_surface,
            },
            gradients = true,
            gradient_rounding = 0,
            gradient_round_only_edges = false,
        },
    }
})

hl.config({
    decoration = {
        rounding = 18,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        dim_inactive = false,
        blur = {
            enabled = true,
            size = 10,
            passes = 2,
            noise = 0,
            contrast = 2,
            brightness = 0.8,
            vibrancy = 0.35,
            vibrancy_darkness = 0.35,
            special = false,
        },
        shadow = {
            enabled = true,
            --offset = "0 1",
            range = 20,
            render_power = 10,
            offset = {0, 2},
            color = Colors.shadow,
        },
    },
})

hl.config({
    master = {
        new_status = "master",
    },
    dwindle = {
       -- pseudotile = true,
        smart_resizing = true,
        force_split = 2,
        preserve_split = true,
        --special_scale_factor = 0.8,
    },
})
