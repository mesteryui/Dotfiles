// Réplica de elephant menus/configuration.lua + menus/sistema.lua
// ("configs": agrupa Packages / Setup / Configuración bajo Configuración).

.pragma library

function info() {
    return { id: "configure", title: "Configuración", tk: "sysmenu.sec_configure", icon: "settings", parent: "main" };
}

function entries() {
    return [
        { id: "cfg-keybinds", title: "Editar atajos de teclado", tk: "sysmenu.cfg-keybinds_t", sub: "hypr keybinds", sk: "sysmenu.cfg-keybinds_s", icon: "keyboard",
          act: { type: "shell", cmd: "emacsclient -c -a emacs ~/.config/hypr/configs/keybinds/" } },
        { id: "cfg-perms", title: "Permisos del compositor", tk: "sysmenu.cfg-perms_t", sub: "permissions", sk: "sysmenu.cfg-perms_s", icon: "security",
          act: { type: "shell", cmd: "emacsclient -c -a emacs \"$XDG_CONFIG_HOME/hypr/configs/permissions.conf\"" } },
        { id: "cfg-monitor", title: "Configuración de monitor", tk: "sysmenu.cfg-monitor_t", sub: "monitors", sk: "sysmenu.cfg-monitor_s", icon: "monitor",
          act: { type: "shell", cmd: "emacsclient -c -a emacs \"$XDG_CONFIG_HOME/hypr/configs/monitors.conf\"" } },
        { id: "cfg-dns", title: "Cambiar DNS", tk: "sysmenu.cfg-dns_t", sub: "dns-manager.sh", sk: "sysmenu.cfg-dns_s", icon: "dns",
          act: { type: "shell", cmd: "xdg-terminal-exec --app-id=local.floating -e dns-manager.sh" } },
        { id: "cfg-power", title: "Perfil de energía", tk: "sysmenu.cfg-power_t", sub: "powerprofilesctl", sk: "sysmenu.cfg-power_s", icon: "battery_charging_full",
          act: { type: "section", id: "powerprofiles" } },
        { id: "cfg-packages", title: "Paquetes", tk: "sysmenu.cfg-packages_t", sub: "Instalar / desinstalar", sk: "sysmenu.cfg-packages_s", icon: "package_2",
          act: { type: "section", id: "packages" } },
        { id: "cfg-setup", title: "Setup", tk: "sysmenu.cfg-setup_t", sub: "Docker, Python", sk: "sysmenu.cfg-setup_s", icon: "construction",
          act: { type: "section", id: "setup" } },
        { id: "cfg-settings", title: "Ajustes del shell", tk: "sysmenu.cfg-settings_t", sub: "panel quickshell", sk: "sysmenu.cfg-settings_s", icon: "tune",
          act: { type: "ipc", call: "ui.settings toggle" } },
        { id: "cfg-dashboard", title: "Panel de control", tk: "sysmenu.cfg-dashboard_t", sub: "dashboard quickshell", sk: "sysmenu.cfg-dashboard_s", icon: "dashboard",
          act: { type: "ipc", call: "dashboard toggle" } }
    ];
}
