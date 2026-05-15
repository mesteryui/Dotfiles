function Toggle_gamemode()
    if hl.get_config("animations.enabled") == true then
        
        hl.config({
        ["animations.enabled"] = false,
    
        ["decoration.shadow.enabled"] = false,
        ["decoration.blur.enabled"] = false,
    
        ["general.gaps_in"] = 0,
        ["general.gaps_out"] = 0,
        ["general.border_size"] = 1,
   
        ["decoration.rounding"] = 0,
        ["decoration.active_opacity"] = 1.0,
        ["decoration.inactive_opacity"] = 1.0,
        ["decoration.fullscreen_opacity"] = 1.0,
    })
    hl.notification.create(
        {
            icon = 1,
            timeout = 1500,
            color = "rgb(40a02b)",
            font_size = 15,
            text = "Gamemode [ON]"
        }
    )
    else
        hl.notification.create({
        icon = 1,
        timeout = 1500,
        color = "rgb(d20f39)",
        font_size = 15,
        text = "Gamemode [OFF]"
    })
    hl.exec_cmd("hyprctl reload")
    end
    
end
