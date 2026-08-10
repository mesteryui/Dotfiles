-- configs/gestures.lua
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

local gestures_expo = { up = "on", down = "off" }

if helper.check_plugin("scrolloverview") then
  hl.plugin.scrolloverview.gesture({fingers = 3, direction = "vertical", disable_inhibit = true}) 
end
--for key, value in pairs(gestures_expo) do
--    hl.gesture({
--        fingers = 3,
--        direction = key,
--        action = function ()
--            if helper.check_plugin("hyprexpo","Hyprexpo") then
--                hl.plugin.hyprexpo.expo(value)
--            end
--        end,
--    })
--end

