// --- Builtin: packages (unified menu system) ---
// Usa el componente base (ver Launcher/CustomMenu.qml).

import qs.Launcher

CustomMenu {
    sectionId: "packages"
    titleFallback: "Paquetes"
    titleKey: "sysmenu.sec_packages"
    iconName: "package_2"
    parentId: "configure"

    entries: [
        shell("pkg-install", "Instalar paquete", "application-installer", "package_2",
            "xdg-terminal-exec --app-id=local.floating -e application-installer",
            { titleKey: "sysmenu.pkg-install_t", subtitleKey: "sysmenu.pkg-install_s" }),
        shell("pkg-remove", "Desinstalar paquete", "application-uninstaller", "delete",
            "xdg-terminal-exec --app-id=local.floating -e application-uninstaller",
            { titleKey: "sysmenu.pkg-remove_t", subtitleKey: "sysmenu.pkg-remove_s" })
    ]
}
