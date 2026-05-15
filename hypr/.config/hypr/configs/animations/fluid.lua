-- configs/animations/fluid.lua
hl.curve("customFade", { type = "bezier", points = { {0.82, 0},    {0.44, 0.77} } })
hl.curve("myBezier",   { type = "bezier", points = { {0.1, 0.01}, {0.38, 1.077} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 7,  bezier = "myBezier", style = "popin" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "fade",        enabled = true, speed = 10, bezier = "default" })
