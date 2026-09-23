// --- Builtin: configure (unified menu system) ---
// Usa el componente base (ver Launcher/MenuDefinition.qml).

import qs.Launcher

MenuDefinition {
    sectionId: "configure"
    titleFallback: "Configuración"
    titleKey: "sysmenu.section_configure"
    iconName: "settings"
    parentId: "main"

    entries: [
        shell("cfg-keybinds", "Editar atajos de teclado", "hypr keybinds", "keyboard",
            "emacsclient -c -a emacs ~/.config/hypr/configs/keybinds/",
            { titleKey: "sysmenu.config_keybinds_title", subtitleKey: "sysmenu.config_keybinds_subtitle" }),
        shell("cfg-perms", "Permisos del compositor", "permissions", "security",
            "emacsclient -c -a emacs \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/configs/permissions.lua\"",
            { titleKey: "sysmenu.config_permissions_title", subtitleKey: "sysmenu.config_permissions_subtitle" }),
        shell("cfg-monitor", "Configuración de monitor", "monitors", "monitor",
            "emacsclient -c -a emacs \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/configs/monitors.lua\"",
            { titleKey: "sysmenu.config_monitor_title", subtitleKey: "sysmenu.config_monitor_subtitle" }),
        shell("cfg-dns", "Cambiar DNS", "dns-manager.sh", "dns",
            "xdg-terminal-exec --app-id=local.floating -e dns-manager.sh",
            { titleKey: "sysmenu.config_dns_title", subtitleKey: "sysmenu.config_dns_subtitle" }),
        submenu("cfg-power", "Perfil de energía", "powerprofilesctl", "battery_charging_full", "powerprofiles",
            { titleKey: "sysmenu.config_power_title", subtitleKey: "sysmenu.config_power_subtitle" }),
        submenu("cfg-packages", "Paquetes", "Instalar / desinstalar", "package_2", "packages",
            { titleKey: "sysmenu.config_packages_title", subtitleKey: "sysmenu.config_packages_subtitle" }),
        submenu("cfg-setup", "Setup", "Docker, Python", "construction", "setup",
            { titleKey: "sysmenu.config_setup_title", subtitleKey: "sysmenu.config_setup_subtitle" }),
        ipc("cfg-settings", "Ajustes del shell", "panel quickshell", "tune",
            "ui.settings toggle",
            { titleKey: "sysmenu.config_settings_title", subtitleKey: "sysmenu.config_settings_subtitle" })
    ]
}
