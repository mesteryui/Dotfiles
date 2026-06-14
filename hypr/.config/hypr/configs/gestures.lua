-- configs/gestures.lua
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})


local gestures_expo = { on = "up", off = "down" }

for key, value in pairs(gestures_expo) do
    hl.gesture({
        fingers = 3,
        direction = value,
        action = function ()
            if helper.check_plugin("hyprexpo","Hyprexpo") then
                hl.plugin.hyprexpo.expo(key)
            end
        end,
    })
end

