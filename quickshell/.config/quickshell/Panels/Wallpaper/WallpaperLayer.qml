import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Capa de fondo estática: una ventana por pantalla, siempre visible.
// Sin proveedores externos: no hay nada que ocultar ni restaurar.
Variants {
    id: root

    model: Quickshell.screens

    delegate: Scope {
        id: delegateScope

        required property ShellScreen modelData

        // Monitor de Hyprland dueño de esta pantalla; puede ser null en el
        // arranque. activeWorkspace es la workspace visible del monitor.
        readonly property var monitor: modelData ? Hyprland.monitors.values.find(m => m.name
                                                                                    === modelData.name) : null
        readonly property int windowsHere: {
            const mon = delegateScope.monitor;
            if (!mon || !mon.activeWorkspace)
                return 0;
            const wsId = mon.activeWorkspace.id;
            return Hyprland.toplevels.values.filter(t => {
                if (!t || !t.workspace || t.workspace.id !== wsId)
                    return false;
                // Misma idea que Switcher.isRealToplevel: ignora toplevels
                // internos/dummy que no son ventanas de verdad.
                const appId = (t.wayland ? t.wayland.appId : "") || t.windowClass || t.initialClass;
                return appId !== undefined && appId !== "";
            }).length;
        }

        WallpaperLayerScreen {
            screen: delegateScope.modelData
            source: Persistent.persistence.currentWallpaper
            windowsOnWorkspace: delegateScope.windowsHere
        }
    }
}
