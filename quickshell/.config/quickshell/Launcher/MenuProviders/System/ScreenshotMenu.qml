// --- Builtin: screenshot (unified menu system) ---
// Usa el componente base (ver Launcher/CustomMenu.qml).

import qs.Launcher

CustomMenu {
    sectionId: "screenshot"
    titleFallback: "Captura"
    titleKey: "sysmenu.sec_screenshot"
    iconName: "screenshot_monitor"
    parentId: "main"

    entries: [
        shell("shot-screen", "Capturar pantalla", "hyprshot output", "screenshot_monitor",
            "sleep 0.5 && hyprshot -m output -m eDP-1",
            { titleKey: "sysmenu.shot-screen_t", subtitleKey: "sysmenu.shot-screen_s" }),
        shell("shot-screen-copy", "Copiar pantalla", "al portapapeles", "content_copy",
            "sleep 0.5 && hyprshot -m output -m eDP-1 --clipboard-only",
            { titleKey: "sysmenu.shot-screen-copy_t", subtitleKey: "sysmenu.shot-screen-copy_s" }),
        shell("shot-region", "Capturar región", "hyprshot region", "crop",
            "sleep 0.5 && hyprshot -m region",
            { titleKey: "sysmenu.shot-region_t", subtitleKey: "sysmenu.shot-region_s" }),
        shell("shot-region-copy", "Copiar región", "al portapapeles", "content_copy",
            "sleep 0.5 && hyprshot -m region --clipboard-only",
            { titleKey: "sysmenu.shot-region-copy_t", subtitleKey: "sysmenu.shot-region-copy_s" }),
        shell("shot-window-copy", "Copiar ventana activa", "al portapapeles", "content_copy",
            "sleep 0.5 && hyprshot -m window -m active --clipboard-only",
            { titleKey: "sysmenu.shot-window-copy_t", subtitleKey: "sysmenu.shot-window-copy_s" }),
        shell("shot-window", "Capturar ventana activa", "hyprshot window", "window",
            "sleep 0.5 && hyprshot -m window -m active",
            { titleKey: "sysmenu.shot-window_t", subtitleKey: "sysmenu.shot-window_s" }),
        shell("shot-annotate", "Capturar con anotaciones", "grim + satty", "edit",
            "grim - | satty --filename - --output-filename \"$HOME/Imágenes/satty-annotated-$(date +'%Y-%m-%d-%H%M%S').png\"",
            { titleKey: "sysmenu.shot-annotate_t", subtitleKey: "sysmenu.shot-annotate_s" }),
        shell("color-picker", "Selector de color", "hyprpicker autocopy", "palette",
            "hyprpicker --autocopy",
            { titleKey: "sysmenu.color-picker_t", subtitleKey: "sysmenu.color-picker_s" })
    ]
}
