-- configs/gestures.lua
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

local gestures_expo = { up = "on", down = "off" }

for key, value in pairs(gestures_expo) do
    hl.gesture({
        fingers = 3,
        direction = key,
        action = function ()
            if helper.check_plugin("hyprexpo","Hyprexpo") then
                hl.plugin.hyprexpo.expo(value)
            end
        end,
    })
end

