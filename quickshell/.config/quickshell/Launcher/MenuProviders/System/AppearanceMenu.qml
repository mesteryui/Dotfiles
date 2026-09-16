// --- Builtin: appearance (unified menu system) ---

import QtQuick

QtObject {
    property string sectionId: "appearance"
    property string titleFallback: "Apariencia"
    property string titleKey: "sysmenu.sec_appearance"
    property string iconName: "palette"
    property string parentId: "main"

    property var entries: [
        { entryId: "theme-wallpapers", titleFallback: "Wallpapers", titleKey: "sysmenu.theme-wallpapers_t", subtitleFallback: "panel del shell", subtitleKey: "sysmenu.theme-wallpapers_s", iconName: "photo_library",
          action: { kind: "ipc", ipcCall: "ui.wallpaperMenu toggleWallpaperMenu" } },
        { entryId: "theme-fastfetch", titleFallback: "Tema Fastfetch", titleKey: "sysmenu.theme-fastfetch_t", subtitleFallback: "elegir config", subtitleKey: "sysmenu.theme-fastfetch_s", iconName: "terminal",
          action: { kind: "section", targetSectionId: "fastfetch" } },
        { entryId: "theme-anims", titleFallback: "Animaciones Hyprland", titleKey: "sysmenu.theme-anims_t", subtitleFallback: "elegir y recargar", subtitleKey: "sysmenu.theme-anims_s", iconName: "animation",
          action: { kind: "section", targetSectionId: "animations" } }
    ]

    function refresh() {}
}
