-- configs/rules_windows/PictureInPicture.lua
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture in Picture)$" }, pin = true, float = true })
