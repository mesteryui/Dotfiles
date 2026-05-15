-- configs/animations/organic-anims.lua
hl.curve("miCurva", { type = "bezier", points = { {0.05, 0.9}, {0.3, 1.0} } })
hl.curve("cohete",  { type = "bezier", points = { {0.05, 1.2}, {0.9, 1.2} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 10, bezier = "cohete", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7,  bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "miCurva" })
