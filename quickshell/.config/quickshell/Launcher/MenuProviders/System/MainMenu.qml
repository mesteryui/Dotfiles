// --- Builtin: main (unified menu system) ---
// Usa el componente base (ver Launcher/CustomMenu.qml).

import qs.Launcher

CustomMenu {
    sectionId: "main"
    titleFallback: "Sistema"
    titleKey: "sysmenu.sec_main"
    iconName: "tune"
    parentId: ""

    entries: [
        shell("about", "Sobre el sistema", "fastfetch en terminal flotante", "info",
            "xdg-terminal-exec --app-id=local.floating -e $SHELL -c 'fastfetch;read -n 1 -s;exit'",
            { titleKey: "sysmenu.about_t", subtitleKey: "sysmenu.about_s" }),
        ipc("update", "Actualizar sistema", "topgrade vía tracker", "refresh",
            "update updateSystem",
            { titleKey: "sysmenu.update_t", subtitleKey: "sysmenu.update_s" }),
        ipc("keybinds", "Atajos de teclado", "Ver cheatsheet", "keyboard",
            "cheatsheet toggle",
            { titleKey: "sysmenu.keybinds_t", subtitleKey: "sysmenu.keybinds_s" }),
        submenu("screenshot", "Captura", "Pantalla, región, ventana, color", "screenshot_monitor", "screenshot",
            { titleKey: "sysmenu.screenshot_t", subtitleKey: "sysmenu.screenshot_s" }),
        submenu("configure", "Configuración", "Hyprland, DNS, energía, paquetes", "settings", "configure",
            { titleKey: "sysmenu.configure_t", subtitleKey: "sysmenu.configure_s" }),
        submenu("appearance", "Apariencia", "Wallpapers, temas, animaciones", "palette", "appearance",
            { titleKey: "sysmenu.appearance_t", subtitleKey: "sysmenu.appearance_s" }),
        submenu("games", "Juegos", "Steam, cartridges", "sports_esports", "games",
            { titleKey: "sysmenu.games_t", subtitleKey: "sysmenu.games_s" }),
        submenu("setup", "Setup", "Docker, Python", "construction", "setup",
            { titleKey: "sysmenu.setup_t", subtitleKey: "sysmenu.setup_s" }),
        ipc("power", "Power / Sesión", "power_menu", "power_settings_new", "ui.powermenu togglePowerMenu",
            { titleKey: "sysmenu.power_t", subtitleKey: "sysmenu.power_s" }) 
    ]
}
