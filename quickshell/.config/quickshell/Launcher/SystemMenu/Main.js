// Sección raíz. Réplica de elephant menus/menu.lua ("main").
// Esquema de item:
//   acción shell: { id, title, sub, icon, act: { type: "shell", cmd: "..." } }
//   acción qs:    { ..., act: { type: "ipc", call: "cheatsheet toggle" } }
//   submenú:      { ..., act: { type: "section", id: "screenshot" } }

.pragma library

function info() {
    return { id: "main", title: "Sistema", tk: "sysmenu.sec_main", icon: "tune", parent: "" };
}

function entries() {
    return [
        { id: "about", title: "Sobre el sistema", tk: "sysmenu.about_t", sub: "fastfetch en terminal flotante", sk: "sysmenu.about_s", icon: "info",
          act: { type: "shell", cmd: "xdg-terminal-exec --app-id=local.floating -e $SHELL -c 'fastfetch;read -n 1 -s;exit'" } },
        { id: "update", title: "Actualizar sistema", tk: "sysmenu.update_t", sub: "topgrade vía tracker", sk: "sysmenu.update_s", icon: "refresh",
          act: { type: "ipc", call: "update updateSystem" } },
        { id: "keybinds", title: "Atajos de teclado", tk: "sysmenu.keybinds_t", sub: "Ver cheatsheet", sk: "sysmenu.keybinds_s", icon: "keyboard",
          act: { type: "ipc", call: "cheatsheet toggle" } },
        { id: "screenshot", title: "Captura", tk: "sysmenu.screenshot_t", sub: "Pantalla, región, ventana, color", sk: "sysmenu.screenshot_s", icon: "screenshot_monitor",
          act: { type: "section", id: "screenshot" } },
        { id: "configure", title: "Configuración", tk: "sysmenu.configure_t", sub: "Hyprland, DNS, energía, paquetes", sk: "sysmenu.configure_s", icon: "settings",
          act: { type: "section", id: "configure" } },
        { id: "appearance", title: "Apariencia", tk: "sysmenu.appearance_t", sub: "Wallpapers, temas, animaciones", sk: "sysmenu.appearance_s", icon: "palette",
          act: { type: "section", id: "appearance" } },
        { id: "games", title: "Juegos", tk: "sysmenu.games_t", sub: "Steam, cartridges", sk: "sysmenu.games_s", icon: "sports_esports",
          act: { type: "section", id: "games" } },
        { id: "setup", title: "Setup", tk: "sysmenu.setup_t", sub: "Docker, Python", sk: "sysmenu.setup_s", icon: "construction",
          act: { type: "section", id: "setup" } },
        { id: "power", title: "Power / Sesión", tk: "sysmenu.power_t", sub: "wlogout", sk: "sysmenu.power_s", icon: "power_settings_new",
          act: { type: "shell", cmd: "wlogout" } },
        { id: "lock", title: "Bloquear pantalla", tk: "sysmenu.lock_t", sub: "quickshell lock", sk: "sysmenu.lock_s", icon: "lock",
          act: { type: "shell", cmd: "qs ipc call lock lock" } }
    ];
}
