// Réplica de elephant menus/games.lua + acceso a cartridges.

.pragma library

function info() {
    return { id: "games", title: "Juegos", tk: "sysmenu.sec_games", icon: "sports_esports", parent: "main" };
}

function entries() {
    return [
        { id: "game-steam", title: "Steam", tk: "sysmenu.game-steam_t", sub: "steam-setup", sk: "sysmenu.game-steam_s", icon: "sports_esports",
          act: { type: "shell", cmd: "kitty --class=float_kitty -e steam-setup" } },
        { id: "game-cartridges", title: "Cartridges", tk: "sysmenu.game-cartridges_t", sub: "biblioteca de juegos", sk: "sysmenu.game-cartridges_s", icon: "gamepad",
          act: { type: "shell", cmd: "cartridges" } }
    ];
}
