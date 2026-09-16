// --- Builtin: games (unified menu system) ---

import QtQuick

QtObject {
    property string sectionId: "games"
    property string titleFallback: "Juegos"
    property string titleKey: "sysmenu.sec_games"
    property string iconName: "sports_esports"
    property string parentId: "main"

    property var entries: [
        { entryId: "game-steam", titleFallback: "Steam", titleKey: "sysmenu.game-steam_t", subtitleFallback: "steam-setup", subtitleKey: "sysmenu.game-steam_s", iconName: "sports_esports",
          action: { kind: "shell", shellCommand: "kitty --class=float_kitty -e steam-setup" } },
        { entryId: "game-cartridges", titleFallback: "Cartridges", titleKey: "sysmenu.game-cartridges_t", subtitleFallback: "biblioteca de juegos", subtitleKey: "sysmenu.game-cartridges_s", iconName: "gamepad",
          action: { kind: "shell", shellCommand: "cartridges" } }
    ]

    function refresh() {}
}
