// --- Builtin: screenshot (unified menu system) ---
// Misma interfaz que un menú propio (ver MenuProviders/MenuProvider.qml).

import QtQuick

QtObject {
    property string sectionId: "screenshot"
    property string titleFallback: "Captura"
    property string titleKey: "sysmenu.sec_screenshot"
    property string iconName: "screenshot_monitor"
    property string parentId: "main"

    property var entries: [
        { entryId: "shot-screen", titleFallback: "Capturar pantalla", titleKey: "sysmenu.shot-screen_t", subtitleFallback: "hyprshot output", subtitleKey: "sysmenu.shot-screen_s", iconName: "screenshot_monitor",
          action: { kind: "shell", shellCommand: "sleep 0.5 && hyprshot -m output -m eDP-1" } },
        { entryId: "shot-screen-copy", titleFallback: "Copiar pantalla", titleKey: "sysmenu.shot-screen-copy_t", subtitleFallback: "al portapapeles", subtitleKey: "sysmenu.shot-screen-copy_s", iconName: "content_copy",
          action: { kind: "shell", shellCommand: "sleep 0.5 && hyprshot -m output -m eDP-1 --clipboard-only" } },
        { entryId: "shot-region", titleFallback: "Capturar región", titleKey: "sysmenu.shot-region_t", subtitleFallback: "hyprshot region", subtitleKey: "sysmenu.shot-region_s", iconName: "crop",
          action: { kind: "shell", shellCommand: "sleep 0.5 && hyprshot -m region" } },
        { entryId: "shot-region-copy", titleFallback: "Copiar región", titleKey: "sysmenu.shot-region-copy_t", subtitleFallback: "al portapapeles", subtitleKey: "sysmenu.shot-region-copy_s", iconName: "content_copy",
          action: { kind: "shell", shellCommand: "sleep 0.5 && hyprshot -m region --clipboard-only" } },
        { entryId: "shot-window-copy", titleFallback: "Copiar ventana activa", titleKey: "sysmenu.shot-window-copy_t", subtitleFallback: "al portapapeles", subtitleKey: "sysmenu.shot-window-copy_s", iconName: "content_copy",
          action: { kind: "shell", shellCommand: "sleep 0.5 && hyprshot -m window -m active --clipboard-only" } },
        { entryId: "shot-window", titleFallback: "Capturar ventana activa", titleKey: "sysmenu.shot-window_t", subtitleFallback: "hyprshot window", subtitleKey: "sysmenu.shot-window_s", iconName: "window",
          action: { kind: "shell", shellCommand: "sleep 0.5 && hyprshot -m window -m active" } },
        { entryId: "shot-annotate", titleFallback: "Capturar con anotaciones", titleKey: "sysmenu.shot-annotate_t", subtitleFallback: "grim + satty", subtitleKey: "sysmenu.shot-annotate_s", iconName: "edit",
          action: { kind: "shell", shellCommand: "grim - | satty --filename - --output-filename \"$HOME/Imágenes/satty-annotated-$(date +'%Y-%m-%d-%H%M%S').png\"" } },
        { entryId: "color-picker", titleFallback: "Selector de color", titleKey: "sysmenu.color-picker_t", subtitleFallback: "hyprpicker autocopy", subtitleKey: "sysmenu.color-picker_s", iconName: "palette",
          action: { kind: "shell", shellCommand: "hyprpicker --autocopy" } }
    ]

    function refresh() {}
}
