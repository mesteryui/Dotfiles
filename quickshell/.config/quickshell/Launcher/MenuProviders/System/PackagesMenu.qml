// --- Builtin: packages (unified menu system) ---
// Usa el componente base (ver Launcher/MenuDefinition.qml).

import qs.Launcher

MenuDefinition {
    sectionId: "packages"
    titleFallback: "Paquetes"
    titleKey: "sysmenu.section_packages"
    iconName: "package_2"
    parentId: "configure"

    entries: [
        shell("pkg-install", "Instalar paquete", "application-installer", "package_2",
            "xdg-terminal-exec --app-id=local.floating -e application-installer",
            { titleKey: "sysmenu.package_install_title", subtitleKey: "sysmenu.package_install_subtitle" }),
        shell("pkg-remove", "Desinstalar paquete", "application-uninstaller", "delete",
            "xdg-terminal-exec --app-id=local.floating -e application-uninstaller",
            { titleKey: "sysmenu.package_remove_title", subtitleKey: "sysmenu.package_remove_subtitle" })
    ]
}
