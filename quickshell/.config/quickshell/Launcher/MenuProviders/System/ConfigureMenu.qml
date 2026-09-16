// --- Builtin: configure (unified menu system) ---

import QtQuick

QtObject {
    property string sectionId: "configure"
    property string titleFallback: "Configuración"
    property string titleKey: "sysmenu.sec_configure"
    property string iconName: "settings"
    property string parentId: "main"

    property var entries: [
        { entryId: "cfg-keybinds", titleFallback: "Editar atajos de teclado", titleKey: "sysmenu.cfg-keybinds_t", subtitleFallback: "hypr keybinds", subtitleKey: "sysmenu.cfg-keybinds_s", iconName: "keyboard",
          action: { kind: "shell", shellCommand: "emacsclient -c -a emacs ~/.config/hypr/configs/keybinds/" } },
        { entryId: "cfg-perms", titleFallback: "Permisos del compositor", titleKey: "sysmenu.cfg-perms_t", subtitleFallback: "permissions", subtitleKey: "sysmenu.cfg-perms_s", iconName: "security",
          action: { kind: "shell", shellCommand: "emacsclient -c -a emacs \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/configs/permissions.lua\"" } },
        { entryId: "cfg-monitor", titleFallback: "Configuración de monitor", titleKey: "sysmenu.cfg-monitor_t", subtitleFallback: "monitors", subtitleKey: "sysmenu.cfg-monitor_s", iconName: "monitor",
          action: { kind: "shell", shellCommand: "emacsclient -c -a emacs \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/configs/monitors.lua\"" } },
        { entryId: "cfg-dns", titleFallback: "Cambiar DNS", titleKey: "sysmenu.cfg-dns_t", subtitleFallback: "dns-manager.sh", subtitleKey: "sysmenu.cfg-dns_s", iconName: "dns",
          action: { kind: "shell", shellCommand: "xdg-terminal-exec --app-id=local.floating -e dns-manager.sh" } },
        { entryId: "cfg-power", titleFallback: "Perfil de energía", titleKey: "sysmenu.cfg-power_t", subtitleFallback: "powerprofilesctl", subtitleKey: "sysmenu.cfg-power_s", iconName: "battery_charging_full",
          action: { kind: "section", targetSectionId: "powerprofiles" } },
        { entryId: "cfg-packages", titleFallback: "Paquetes", titleKey: "sysmenu.cfg-packages_t", subtitleFallback: "Instalar / desinstalar", subtitleKey: "sysmenu.cfg-packages_s", iconName: "package_2",
          action: { kind: "section", targetSectionId: "packages" } },
        { entryId: "cfg-setup", titleFallback: "Setup", titleKey: "sysmenu.cfg-setup_t", subtitleFallback: "Docker, Python", subtitleKey: "sysmenu.cfg-setup_s", iconName: "construction",
          action: { kind: "section", targetSectionId: "setup" } },
        { entryId: "cfg-settings", titleFallback: "Ajustes del shell", titleKey: "sysmenu.cfg-settings_t", subtitleFallback: "panel quickshell", subtitleKey: "sysmenu.cfg-settings_s", iconName: "tune",
          action: { kind: "ipc", ipcCall: "ui.settings toggle" } },
        { entryId: "cfg-dashboard", titleFallback: "Panel de control", titleKey: "sysmenu.cfg-dashboard_t", subtitleFallback: "dashboard quickshell", subtitleKey: "sysmenu.cfg-dashboard_s", iconName: "dashboard",
          action: { kind: "ipc", ipcCall: "dashboard toggle" } }
    ]

    function refresh() {}
}
