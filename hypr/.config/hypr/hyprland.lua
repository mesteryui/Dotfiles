local terminal = "kitty"
local fileManager = "yazi"
local menu = "walker"

local mainMod = "SUPER"

for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod.." + ".. key, hl.dsp.focus({workspace = i}))
  hl.bind(mainMod.." + SHIFT +"..key, hl.dsp.move({workspace = i}))
end
