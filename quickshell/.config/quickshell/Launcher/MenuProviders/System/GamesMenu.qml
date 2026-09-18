// --- Builtin: games (unified menu system) ---
// Usa el componente base (ver Launcher/CustomMenu.qml).

import qs.Launcher

CustomMenu {
    sectionId: "games"
    titleFallback: "Juegos"
    titleKey: "sysmenu.sec_games"
    iconName: "sports_esports"
    parentId: "main"

    entries: [
        shell("game-steam", "Steam", "steam-setup", "sports_esports",
            "kitty --class=float_kitty -e steam-setup",
            { titleKey: "sysmenu.game-steam_t", subtitleKey: "sysmenu.game-steam_s" })
    ]
}
