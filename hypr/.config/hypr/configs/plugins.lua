-- configs/plugins.lua
helper.load_plugin_conf("hyprbars", function (p)
    hl.config({
        ["plugin.hyprbars"] = {
            enabled = false,
            bar_height = 20,
            on_double_click = "hyprctl dispatch 'hl.dsp.window.fullscreen()'",
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
            gaps_in = 5,
            gaps_out = 3,
            keynav_enable = 1,
            label_enable = 0,
            border_width = 2,
            border_color_current = Colors.primary,
            bg_col = Colors.surface,
            workspace_method = "center current", -- [center/first] [workspace] e.g. first 1 or center m+1
                                          -- Per-monitor: DP-1 first 1, HDMI-1 center current

            gesture_distance = 200, -- how far is the "max" for the gesture
        }
    })
end)

