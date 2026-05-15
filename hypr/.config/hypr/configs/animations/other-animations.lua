-- configs/animations/other-animations.lua
hl.curve("md3_standard", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "md3_standard", style = "popin 60%" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4, bezier = "md3_standard", style = "popin 60%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "md3_standard", style = "popin 80%" })

hl.animation({ leaf = "layers",    enabled = true, speed = 3, bezier = "md3_standard", style = "popin" })
hl.animation({ leaf = "layersIn",  enabled = true, speed = 3, bezier = "md3_standard", style = "popin" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "md3_standard", style = "popin" })

hl.animation({ leaf = "fade",             enabled = true, speed = 3, bezier = "md3_standard" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "md3_standard", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "md3_standard", style = "slidevert" })
hl.animation({ leaf = "border",           enabled = true, speed = 10, bezier = "default" })
