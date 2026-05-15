-- configs/plugins.lua

if not hl.plugin then
    return
end

if hl.plugin.hyprbars then

    hl.config({
        ["plugin.hyprbars"] = {
            enabled = false,
            bar_height = 20,
            on_double_click = "hyprctl dispatch fullscreen 1",
        }
    })

    hl.plugin.hyprbars.add_button({
        bg_color = Colors.error,
        fg_color = Colors.on_error,
        size = 13,
        icon = "X",
        action = "hyprctl dispatch killactive",
    })

    hl.plugin.hyprbars.add_button({
        bg_color = Colors.primary_fixed,
        fg_color = Colors.on_primary_fixed,
        size = 13,
        icon = "_",
        action = "hyprctl dispatch fullscreen 1",
    })
end

if hl.plugin.hyprexpo then
    hl.config({
        ["plugin.hyprexpo"] = {
            columns = 3,
            gap_size = 5,
            bg_col = Colors.surface,
            workspace_method = "center current", -- [center/first] [workspace] e.g. first 1 or center m+1
                                          -- Per-monitor: DP-1 first 1, HDMI-1 center current

            gesture_distance = 200, -- how far is the "max" for the gesture
        }
    })
end

