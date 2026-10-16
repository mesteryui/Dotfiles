-- configs/monitors.lua
local mirroring = false

hl.monitor({ output = "", mode = "highrr", position = "auto" })

hl.monitor({
	output = DefaultMonitor,
	scale = "1.80",
})

--hl.config({ experimental = { hdr = true, wide_color_gamut = true }, render = { explicit_sync = 1 } })

hl.monitor({
	output = "HDMI-A-1",
	mode = "preferred",
	mirror = mirroring and DefaultMonitor or nil,
})
