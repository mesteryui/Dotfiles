// --- Builtin: games (unified menu system) ---
// Usa el componente base (ver Launcher/MenuDefinition.qml).

import qs.Launcher

MenuDefinition {
    sectionId: "games"
    titleFallback: "Juegos"
    titleKey: "sysmenu.section_games"
    iconName: "sports_esports"
    parentId: "main"

    entries: [
        shell("game-steam", "Steam", "steam-setup", "sports_esports",
            "kitty --class=float_kitty -e steam-setup",
            { titleKey: "sysmenu.game_steam_title", subtitleKey: "sysmenu.game_steam_subtitle" })
    ]
}
