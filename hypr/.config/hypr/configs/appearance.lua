-- configs/appearance.lua
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border = { colors = {Colors.primary, Colors.tertiary}, angle = 45 },
            inactive_border = { colors = {Colors.on_secondary, Colors.surface_container}, angle = 45 },
        },
        resize_on_border = true,
        resize_corner = 3,
        allow_tearing = false,
        no_focus_fallback = true,
        layout = "dwindle",
    },
    cursor = {
        zoom_factor = 1,
        zoom_rigid = false,
        hotspot_padding = 1,
        hide_on_key_press = true,
        no_hardware_cursors = true,
        enable_hyprcursor = true,
        no_warps = true,
        inactive_timeout = 7
    },
    render = {
        direct_scanout = 0,
    },
    xwayland = {
        enabled = true,
        force_zero_scaling = false,
    },
})

hl.config({
    group = {
        col = {
            border_active = { colors = {Colors.primary, Colors.tertiary}, angle = 45 },
            border_inactive = { colors = {Colors.on_secondary, Colors.surface_container}, angle = 45 },
            border_locked_active = 1,
            border_locked_inactive = 1,
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
        rounding = 16,
        rounding_power = 3,
        active_opacity = 1.0,
        inactive_opacity = 0.90,
        dim_inactive = false,
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            noise = 0.05,
            contrast = 0.9,
            brightness = 0.96,
            vibrancy = 0.6,
            popups = true,
            ignore_opacity = true,
            input_methods = true,
            new_optimizations = true,
            special = true,
            xray = false,
        },
        shadow = {
            enabled = true,
            --offset = "0 1",
            range = 13,
            render_power = 3,
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
        force_split = 2,
        preserve_split = true,
        --special_scale_factor = 0.8,
    },
    scrolling = {
        fullscreen_on_one_column = true,
        focus_fit_method = 1,
        column_width = 0.985,
        follow_focus = 1,
    },
})
