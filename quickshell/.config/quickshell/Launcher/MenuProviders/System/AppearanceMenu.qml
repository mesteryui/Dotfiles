// --- Builtin: appearance (unified menu system) ---
// Usa el componente base (ver Launcher/MenuDefinition.qml).

import qs.Launcher

MenuDefinition {
    sectionId: "appearance"
    titleFallback: "Apariencia"
    titleKey: "sysmenu.section_appearance"
    iconName: "palette"
    parentId: "main"

    entries: [
        ipc("theme-wallpapers", "Wallpapers", "panel del shell", "photo_library",
            "ui.wallpaperMenu toggleWallpaperMenu",
            { titleKey: "sysmenu.theme_wallpapers_title", subtitleKey: "sysmenu.theme_wallpapers_subtitle" }),
        ipc("theme-wallhaven", "Wallhaven", "descargar fondos de wallhaven.cc", "cloud_download",
            "ui.wallhaven toggleWallhaven",
            { titleKey: "sysmenu.theme_wallhaven_title", subtitleKey: "sysmenu.theme_wallhaven_subtitle" }),
        submenu("theme-fastfetch", "Tema Fastfetch", "elegir config", "terminal", "fastfetch",
            { titleKey: "sysmenu.theme_fastfetch_title", subtitleKey: "sysmenu.theme_fastfetch_subtitle" }),
        submenu("theme-anims", "Animaciones Hyprland", "elegir y recargar", "animation", "animations",
            { titleKey: "sysmenu.theme_animations_title", subtitleKey: "sysmenu.theme_animations_subtitle" })
    ]
}
