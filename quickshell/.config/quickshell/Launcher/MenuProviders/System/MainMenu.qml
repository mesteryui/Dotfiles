// --- Builtin: main (unified menu system) ---
// Parte del sistema unificado: todo menú (incluidos los internos) es un
// provider QML con la misma interfaz que MenuProviders/MenuProvider.qml.
// Los internos viven en MenuProviders/System/*.qml, los tuyos en MenuProviders/*.qml.
// El Registry no distingue el origen: solo pregunta a CustomMenuService.

import QtQuick

QtObject {
    property string sectionId: "main"
    property string titleFallback: "Sistema"
    property string titleKey: "sysmenu.sec_main"
    property string iconName: "tune"
    property string parentId: ""

    property var entries: [
        { entryId: "about", titleFallback: "Sobre el sistema", titleKey: "sysmenu.about_t", subtitleFallback: "fastfetch en terminal flotante", subtitleKey: "sysmenu.about_s", iconName: "info",
          action: { kind: "shell", shellCommand: "xdg-terminal-exec --app-id=local.floating -e $SHELL -c 'fastfetch;read -n 1 -s;exit'" } },
        { entryId: "update", titleFallback: "Actualizar sistema", titleKey: "sysmenu.update_t", subtitleFallback: "topgrade vía tracker", subtitleKey: "sysmenu.update_s", iconName: "refresh",
          action: { kind: "ipc", ipcCall: "update updateSystem" } },
        { entryId: "keybinds", titleFallback: "Atajos de teclado", titleKey: "sysmenu.keybinds_t", subtitleFallback: "Ver cheatsheet", subtitleKey: "sysmenu.keybinds_s", iconName: "keyboard",
          action: { kind: "ipc", ipcCall: "cheatsheet toggle" } },
        { entryId: "screenshot", titleFallback: "Captura", titleKey: "sysmenu.screenshot_t", subtitleFallback: "Pantalla, región, ventana, color", subtitleKey: "sysmenu.screenshot_s", iconName: "screenshot_monitor",
          action: { kind: "section", targetSectionId: "screenshot" } },
        { entryId: "configure", titleFallback: "Configuración", titleKey: "sysmenu.configure_t", subtitleFallback: "Hyprland, DNS, energía, paquetes", subtitleKey: "sysmenu.configure_s", iconName: "settings",
          action: { kind: "section", targetSectionId: "configure" } },
        { entryId: "appearance", titleFallback: "Apariencia", titleKey: "sysmenu.appearance_t", subtitleFallback: "Wallpapers, temas, animaciones", subtitleKey: "sysmenu.appearance_s", iconName: "palette",
          action: { kind: "section", targetSectionId: "appearance" } },
        { entryId: "games", titleFallback: "Juegos", titleKey: "sysmenu.games_t", subtitleFallback: "Steam, cartridges", subtitleKey: "sysmenu.games_s", iconName: "sports_esports",
          action: { kind: "section", targetSectionId: "games" } },
        { entryId: "setup", titleFallback: "Setup", titleKey: "sysmenu.setup_t", subtitleFallback: "Docker, Python", subtitleKey: "sysmenu.setup_s", iconName: "construction",
          action: { kind: "section", targetSectionId: "setup" } },
        { entryId: "power", titleFallback: "Power / Sesión", titleKey: "sysmenu.power_t", subtitleFallback: "wlogout", subtitleKey: "sysmenu.power_s", iconName: "power_settings_new",
          action: { kind: "shell", shellCommand: "wlogout" } },
        { entryId: "lock", titleFallback: "Bloquear pantalla", titleKey: "sysmenu.lock_t", subtitleFallback: "quickshell lock", subtitleKey: "sysmenu.lock_s", iconName: "lock",
          action: { kind: "shell", shellCommand: "qs ipc call lockscreen lock" } }
    ]

    function refresh() {}
}
