// --- Builtin: configure (unified menu system) ---
// Usa el componente base (ver Launcher/CustomMenu.qml).

import qs.Launcher

CustomMenu {
    sectionId: "configure"
    titleFallback: "Configuración"
    titleKey: "sysmenu.sec_configure"
    iconName: "settings"
    parentId: "main"

    entries: [
        shell("cfg-keybinds", "Editar atajos de teclado", "hypr keybinds", "keyboard",
            "emacsclient -c -a emacs ~/.config/hypr/configs/keybinds/",
            { titleKey: "sysmenu.cfg-keybinds_t", subtitleKey: "sysmenu.cfg-keybinds_s" }),
        shell("cfg-perms", "Permisos del compositor", "permissions", "security",
            "emacsclient -c -a emacs \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/configs/permissions.lua\"",
            { titleKey: "sysmenu.cfg-perms_t", subtitleKey: "sysmenu.cfg-perms_s" }),
        shell("cfg-monitor", "Configuración de monitor", "monitors", "monitor",
            "emacsclient -c -a emacs \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/configs/monitors.lua\"",
            { titleKey: "sysmenu.cfg-monitor_t", subtitleKey: "sysmenu.cfg-monitor_s" }),
        shell("cfg-dns", "Cambiar DNS", "dns-manager.sh", "dns",
            "xdg-terminal-exec --app-id=local.floating -e dns-manager.sh",
            { titleKey: "sysmenu.cfg-dns_t", subtitleKey: "sysmenu.cfg-dns_s" }),
        submenu("cfg-power", "Perfil de energía", "powerprofilesctl", "battery_charging_full", "powerprofiles",
            { titleKey: "sysmenu.cfg-power_t", subtitleKey: "sysmenu.cfg-power_s" }),
        submenu("cfg-packages", "Paquetes", "Instalar / desinstalar", "package_2", "packages",
            { titleKey: "sysmenu.cfg-packages_t", subtitleKey: "sysmenu.cfg-packages_s" }),
        submenu("cfg-setup", "Setup", "Docker, Python", "construction", "setup",
            { titleKey: "sysmenu.cfg-setup_t", subtitleKey: "sysmenu.cfg-setup_s" }),
        ipc("cfg-settings", "Ajustes del shell", "panel quickshell", "tune",
            "ui.settings toggle",
            { titleKey: "sysmenu.cfg-settings_t", subtitleKey: "sysmenu.cfg-settings_s" })
    ]
}
