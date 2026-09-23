// --- Builtin: main (unified menu system) ---
// Usa el componente base (ver Launcher/MenuDefinition.qml).

import qs.Launcher

MenuDefinition {
    sectionId: "main"
    titleFallback: "Sistema"
    titleKey: "sysmenu.section_main"
    iconName: "tune"
    parentId: ""

    entries: [
        shell("about", "Sobre el sistema", "fastfetch en terminal flotante", "info",
            "xdg-terminal-exec --app-id=local.floating -e $SHELL -c 'fastfetch;read -n 1 -s;exit'",
            { titleKey: "sysmenu.about_title", subtitleKey: "sysmenu.about_subtitle" }),
        ipc("update", "Actualizar sistema", "topgrade vía tracker", "refresh",
            "update updateSystem",
            { titleKey: "sysmenu.update_title", subtitleKey: "sysmenu.update_subtitle" }),
        ipc("keybinds", "Atajos de teclado", "Ver cheatsheet", "keyboard",
            "cheatsheet toggle",
            { titleKey: "sysmenu.keybinds_title", subtitleKey: "sysmenu.keybinds_subtitle" }),
        submenu("screenshot", "Captura", "Pantalla, región, ventana, color", "screenshot_monitor", "screenshot",
            { titleKey: "sysmenu.screenshot_title", subtitleKey: "sysmenu.screenshot_subtitle" }),
        submenu("configure", "Configuración", "Hyprland, DNS, energía, paquetes", "settings", "configure",
            { titleKey: "sysmenu.configure_title", subtitleKey: "sysmenu.configure_subtitle" }),
        submenu("appearance", "Apariencia", "Wallpapers, temas, animaciones", "palette", "appearance",
            { titleKey: "sysmenu.appearance_title", subtitleKey: "sysmenu.appearance_subtitle" }),
        submenu("games", "Juegos", "Steam, cartridges", "sports_esports", "games",
            { titleKey: "sysmenu.games_title", subtitleKey: "sysmenu.games_subtitle" }),
        submenu("setup", "Setup", "Docker, Python", "construction", "setup",
            { titleKey: "sysmenu.setup_title", subtitleKey: "sysmenu.setup_subtitle" }),
        ipc("power", "Power / Sesión", "power_menu", "power_settings_new", "ui.powermenu togglePowerMenu",
            { titleKey: "sysmenu.power_title", subtitleKey: "sysmenu.power_subtitle" }) 
    ]
}
