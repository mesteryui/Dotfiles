pragma Singleton

import Quickshell
import Quickshell.Hyprland

// Pantalla con foco del compositor, con fallback a la primera:
// Hyprland.focusedMonitor puede ser null en el arranque o al
// desconectar monitores. Fuente única para no triplicar la expresión
// (la usaban BaseOSD, WallpaperMenu y WallhavenWindow cada uno a su manera).
Singleton {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
}
