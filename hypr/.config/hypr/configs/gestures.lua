-- configs/gestures.lua
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.gesture({
     fingers = 3,
     direction = "up",
     action = function ()
        hl.plugin.hyprexpo.expo("on")
     end,
})
hl.gesture({
     fingers = 3,
     direction = "down",
     action = function ()
        hl.plugin.hyprexpo.expo("off")
     end,
})
