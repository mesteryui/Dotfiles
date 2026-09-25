// --- Builtin: screenshot (unified menu system) ---
// Usa el componente base (ver Launcher/MenuDefinition.qml).

import qs.Launcher

MenuDefinition {
    sectionId: "screenshot"
    titleFallback: "Captura"
    titleKey: "sysmenu.section_screenshot"
    iconName: "screenshot_monitor"
    parentId: "main"

    entries: [shell("shot-screen", "Capturar pantalla", "hyprshot output", "screenshot_monitor", "sleep 0.5 && hyprshot -m output -m eDP-1", {
            titleKey: "sysmenu.shot_screen_title",
            subtitleKey: "sysmenu.shot_screen_subtitle"
        }), shell("shot-screen-copy", "Copiar pantalla", "al portapapeles", "content_copy", "sleep 0.5 && hyprshot -m output -m eDP-1 --clipboard-only", {
            titleKey: "sysmenu.shot_screen_copy_title",
            subtitleKey: "sysmenu.shot_screen_copy_subtitle"
        }), shell("shot-region", "Capturar región", "hyprshot region", "crop", "sleep 0.5 && hyprshot -m region", {
            titleKey: "sysmenu.shot_region_title",
            subtitleKey: "sysmenu.shot_region_subtitle"
        }), shell("shot-region-copy", "Copiar región", "al portapapeles", "content_copy", "sleep 0.5 && hyprshot -m region --clipboard-only", {
            titleKey: "sysmenu.shot_region_copy_title",
            subtitleKey: "sysmenu.shot_region_copy_subtitle"
        }), shell("shot-window-copy", "Copiar ventana activa", "al portapapeles", "content_copy", "sleep 0.5 && hyprshot -m window -m active --clipboard-only", {
            titleKey: "sysmenu.shot_window_copy_title",
            subtitleKey: "sysmenu.shot_window_copy_subtitle"
        }), shell("shot-window", "Capturar ventana activa", "hyprshot window", "window", "sleep 0.5 && hyprshot -m window -m active", {
            titleKey: "sysmenu.shot_window_title",
            subtitleKey: "sysmenu.shot_window_subtitle"
        }), shell("shot-annotate", "Capturar con anotaciones", "grim + satty", "edit", "grim - | satty --filename - --output-filename \"$HOME/Imágenes/satty-annotated-$(date +'%Y-%m-%d-%H%M%S').png\"", {
            titleKey: "sysmenu.shot_annotate_title",
            subtitleKey: "sysmenu.shot_annotate_subtitle"
        })]
}
