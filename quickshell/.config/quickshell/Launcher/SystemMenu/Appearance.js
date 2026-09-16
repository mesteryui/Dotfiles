// Réplica de elephant menus/themes.lua ("themes", parent: main).
// Fastfetch/animaciones son submenús dinámicos de SystemMenuService y
// Wallpapers abre el panel ya existente del shell (ui.wallpaperMenu).

.pragma library

function info() {
    return { id: "appearance", title: "Apariencia", tk: "sysmenu.sec_appearance", icon: "palette", parent: "main" };
}

function entries() {
    return [
        { id: "theme-wallpapers", title: "Wallpapers", tk: "sysmenu.theme-wallpapers_t", sub: "panel del shell", sk: "sysmenu.theme-wallpapers_s", icon: "photo_library",
          act: { type: "ipc", call: "ui.wallpaperMenu toggleWallpaperMenu" } },
        { id: "theme-fastfetch", title: "Tema Fastfetch", tk: "sysmenu.theme-fastfetch_t", sub: "elegir config", sk: "sysmenu.theme-fastfetch_s", icon: "terminal",
          act: { type: "section", id: "fastfetch" } },
        { id: "theme-anims", title: "Animaciones Hyprland", tk: "sysmenu.theme-anims_t", sub: "elegir y recargar", sk: "sysmenu.theme-anims_s", icon: "animation",
          act: { type: "section", id: "animations" } }
    ];
}
