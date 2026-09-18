// --- Builtin: appearance (unified menu system) ---
// Usa el componente base (ver Launcher/CustomMenu.qml).

import qs.Launcher

CustomMenu {
    sectionId: "appearance"
    titleFallback: "Apariencia"
    titleKey: "sysmenu.sec_appearance"
    iconName: "palette"
    parentId: "main"

    entries: [
        ipc("theme-wallpapers", "Wallpapers", "panel del shell", "photo_library",
            "ui.wallpaperMenu toggleWallpaperMenu",
            { titleKey: "sysmenu.theme-wallpapers_t", subtitleKey: "sysmenu.theme-wallpapers_s" }),
        submenu("theme-fastfetch", "Tema Fastfetch", "elegir config", "terminal", "fastfetch",
            { titleKey: "sysmenu.theme-fastfetch_t", subtitleKey: "sysmenu.theme-fastfetch_s" }),
        submenu("theme-anims", "Animaciones Hyprland", "elegir y recargar", "animation", "animations",
            { titleKey: "sysmenu.theme-anims_t", subtitleKey: "sysmenu.theme-anims_s" })
    ]
}
