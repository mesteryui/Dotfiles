// Réplica de elephant menus/packages.lua + installation.lua + uninstallation.lua.

.pragma library

function info() {
    return { id: "packages", title: "Paquetes", tk: "sysmenu.sec_packages", icon: "package_2", parent: "configure" };
}

function entries() {
    return [
        { id: "pkg-install", title: "Instalar paquete", tk: "sysmenu.pkg-install_t", sub: "application-installer", sk: "sysmenu.pkg-install_s", icon: "package_2",
          act: { type: "shell", cmd: "xdg-terminal-exec --app-id=local.floating -e application-installer" } },
        { id: "pkg-remove", title: "Desinstalar paquete", tk: "sysmenu.pkg-remove_t", sub: "application-uninstaller", sk: "sysmenu.pkg-remove_s", icon: "delete",
          act: { type: "shell", cmd: "xdg-terminal-exec --app-id=local.floating -e application-uninstaller" } }
    ];
}
