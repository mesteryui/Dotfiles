// --- Builtin: packages (unified menu system) ---

import QtQuick

QtObject {
    property string sectionId: "packages"
    property string titleFallback: "Paquetes"
    property string titleKey: "sysmenu.sec_packages"
    property string iconName: "package_2"
    property string parentId: "configure"

    property var entries: [
        { entryId: "pkg-install", titleFallback: "Instalar paquete", titleKey: "sysmenu.pkg-install_t", subtitleFallback: "application-installer", subtitleKey: "sysmenu.pkg-install_s", iconName: "package_2",
          action: { kind: "shell", shellCommand: "xdg-terminal-exec --app-id=local.floating -e application-installer" } },
        { entryId: "pkg-remove", titleFallback: "Desinstalar paquete", titleKey: "sysmenu.pkg-remove_t", subtitleFallback: "application-uninstaller", subtitleKey: "sysmenu.pkg-remove_s", iconName: "delete",
          action: { kind: "shell", shellCommand: "xdg-terminal-exec --app-id=local.floating -e application-uninstaller" } }
    ]

    function refresh() {}
}
