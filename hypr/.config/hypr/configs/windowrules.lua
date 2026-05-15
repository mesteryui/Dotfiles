-- configs/windowrules.lua
require("configs.rules_windows.btop")

hl.window_rule({ match = { class = "vesktop" }, workspace = 5 })
hl.window_rule({ match = { class = "gimp" },    workspace = 4 })

hl.window_rule({ match = { class = "mpv" }, float = true, center = true, size = "900 500" })

require("configs.rules_windows.PictureInPicture")

hl.window_rule({
    name = "floating-utils",
    match = {
        class = "^(blueberry.py|nm-applet|kvantummanager|.*dialog.*|org.localsend.localsend_app)$",
        title = "^(Acerca.*|Watering)$",
    },
    float = true,
    center = true,
})

hl.window_rule({ match = { class = "^(.*Cartridges)$" }, float = true })
hl.window_rule({ match = { class = "xdg-desktop-portal-gtk" }, size = "35% 50%" })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk)$" }, float = true })

require("configs.rules_windows.jetbrains")
require("configs.rules_windows.terminals")
require("configs.rules_windows.someFixes")
require("configs.rules_windows.steam")

hl.window_rule({
    name = "tag-floating-term",
    match = { tag = "floating-term" },
    float = true,
    center = true,
    size = "800 700",
})

hl.window_rule({
    name = "tag-floating-window",
    match = { tag = "floating-window" },
    float = true,
    center = true,
    size = "900 800",
})

-- ASIGNACIÓN DE TAGS
hl.window_rule({ match = { class = "^(local\\.floating)$" }, tag = "+floating-term" })
hl.window_rule({
    match = { class = "^(xdg-desktop-portal-gtk|imv|.*Showtime|.*Cartridges|nwg-look|qt5ct|qt6ct|com.github.rafostar.Clapper|pavucontrol|waypaper|waifudownloader|catgirldownloader|com.gabm.satty)$" },
    tag = "+floating-window",
})

hl.window_rule({
    name = "calculator-fix",
    match = { class = "^(galculator)$" },
    float = true,
    size = "100 200",
})

--hl.window_rule({ match = { class = "^(org\\.quickshell)$" }, float = true })

--hl.workspace_rule({ workspace = 2, layoutopt = "direction:right" })
