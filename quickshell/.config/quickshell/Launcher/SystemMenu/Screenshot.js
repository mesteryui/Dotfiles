// Réplica de elephant menus/screenshot-opt.toml ("screenshot", parent: main)
// + selector de color (antes en binds de Hyprland). Sin cambios de comandos.

.pragma library

function info() {
    return { id: "screenshot", title: "Captura", tk: "sysmenu.sec_screenshot", icon: "screenshot_monitor", parent: "main" };
}

function entries() {
    return [
        { id: "shot-screen", title: "Capturar pantalla", tk: "sysmenu.shot-screen_t", sub: "hyprshot output", sk: "sysmenu.shot-screen_s", icon: "screenshot_monitor",
          act: { type: "shell", cmd: "sleep 0.5 && hyprshot -m output -m eDP-1" } },
        { id: "shot-screen-copy", title: "Copiar pantalla", tk: "sysmenu.shot-screen-copy_t", sub: "al portapapeles", sk: "sysmenu.shot-screen-copy_s", icon: "content_copy",
          act: { type: "shell", cmd: "sleep 0.5 && hyprshot -m output -m eDP-1 --clipboard-only" } },
        { id: "shot-region", title: "Capturar región", tk: "sysmenu.shot-region_t", sub: "hyprshot region", sk: "sysmenu.shot-region_s", icon: "crop",
          act: { type: "shell", cmd: "sleep 0.5 && hyprshot -m region" } },
        { id: "shot-region-copy", title: "Copiar región", tk: "sysmenu.shot-region-copy_t", sub: "al portapapeles", sk: "sysmenu.shot-region-copy_s", icon: "content_copy",
          act: { type: "shell", cmd: "sleep 0.5 && hyprshot -m region --clipboard-only" } },
        { id: "shot-window-copy", title: "Copiar ventana activa", tk: "sysmenu.shot-window-copy_t", sub: "al portapapeles", sk: "sysmenu.shot-window-copy_s", icon: "content_copy",
          act: { type: "shell", cmd: "sleep 0.5 && hyprshot -m window -m active --clipboard-only" } },
        { id: "shot-window", title: "Capturar ventana activa", tk: "sysmenu.shot-window_t", sub: "hyprshot window", sk: "sysmenu.shot-window_s", icon: "window",
          act: { type: "shell", cmd: "sleep 0.5 && hyprshot -m window -m active" } },
        { id: "shot-annotate", title: "Capturar con anotaciones", tk: "sysmenu.shot-annotate_t", sub: "grim + satty", sk: "sysmenu.shot-annotate_s", icon: "edit",
          act: { type: "shell", cmd: "grim - | satty --filename - --output-filename \"$HOME/Imágenes/satty-annotated-$(date +'%Y-%m-%d-%H%M%S').png\"" } },
        { id: "color-picker", title: "Selector de color", tk: "sysmenu.color-picker_t", sub: "hyprpicker autocopy", sk: "sysmenu.color-picker_s", icon: "palette",
          act: { type: "shell", cmd: "hyprpicker --autocopy" } }
    ];
}
