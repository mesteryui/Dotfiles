-- configs/plugins.lua
helper.load_plugin_conf("hyprbars", function (p)
    hl.config({
        ["plugin.hyprbars"] = {
            enabled = false,
            bar_height = 20,
            on_double_click = "hyprctl dispatch 'hl.dsp.window.fullscreen()'",
            bar_text_font = "Google Sans Flex",
            bar_text_size = 12,
        }
    })

    p.add_button({
        bg_color = Colors.error,
        fg_color = Colors.on_error,
        size = 13,
        icon = "X",
        action = "hyprctl dispatch 'hl.dsp.window.close()'",
    })

    p.add_button({
        bg_color = Colors.primary_fixed,
        fg_color = Colors.on_primary_fixed,
        size = 13,
        icon = "_",
        action = "hyprctl dispatch 'hl.dsp.window.fullscreen()'",
    })
end)
helper.load_plugin_conf("dynamic_cursors", function()
    hl.config({
        ["plugin.dynamic_cursors"] = {
            enabled = true,
            mode = "tilt",
            hyprcursor = {
                nearest = true,
                enabled = true,
                resolution = -1,
                fallback = "clientside",
            },
            shake = {
                enabled = true,
                --nearest = true,
                threshold = 6.0,
                base = 4.0,
                speed = 4.0,
                influence = 0.0,
                limit = 0.0,
                timeout = 2000,
                effects = true,
                ipc = false,
            },
            tilt = {
                limit = 5000,
                --["function"] = "negative_quadratic",
                window = 100,
            },
        }
    })
end)
helper.load_plugin_conf("hyprexpo", function ()
    hl.config({
        ["plugin.hyprexpo"] = {
            columns = 3,
            gaps_in = 8,
            gaps_out = 24,              -- más aire en los bordes, se siente más "card"
            keynav_enable = 1,

            -- Redondeo estilo MD3 (tus cards ya usan esto en el resto del shell)
            tile_rounding = 20,          -- ajusta a tu radius token si tienes uno (ej. 16-28)
            tile_rounding_power = 2.0,

            -- Bordes: usa el trío completo, no solo current
            border_width = 2,
            border_color_current = Colors.primary,
            border_color_focus = Colors.tertiary,   -- diferenciar focus de current
            border_color_hover = Colors.outline,    -- sutil, no compite con current

            bg_col = Colors.surfaceContainerLow,     -- mejor que surface a secas, da profundidad

            -- Labels: si los activas, estilízalos en vez de dejarlos default
            label_enable = 0,
            label_show = "hover+focus",   -- menos ruido visual que "always"
            label_bg_enable = 1,
            label_bg_shape = "rounded",
            label_bg_rounding = 10,
            label_bg_color = Colors.surface_container_highest,
            label_color_default = Colors.on_surface_variant,
            label_color_current = Colors.primary,
            label_color_focus = Colors.tertiary,
            label_font_family = "Google Sans Flex",  -- consistencia con el resto del shell

            workspace_method = "center current",
            gesture_distance = 200,
        }
    })
end)

helper.load_plugin_conf("scrolloverview", function ()
  hl.config({
    ["plugin.scrolloverview"] = {
            gesture_distance = 300, -- how far is the "max" for the gesture
            scale = 0.5, -- preferred overview scale
            workspace_gap = 100,
            layout = "vertical", -- vertical or horizontal
            wallpaper = 0, -- 0: global only, 1: per-workspace only, 2: both
            blur = false, -- blur only the main overview wallpaper

            shadow = {
                enabled = false,
                range = 50,
                render_power = 3,
                color = 0xee1a1a1a,
            },
        },
    })
end)

