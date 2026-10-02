import QtQuick
import Quickshell
import qs.Core.Modules

// Capa de fondo estática: una ventana por pantalla, siempre visible.
// Sin proveedores externos: no hay nada que ocultar ni restaurar.
Variants {
    id: root

    model: Quickshell.screens

    delegate: Scope {
        id: delegateScope

        required property ShellScreen modelData

        WallpaperLayerScreen {
            screen: delegateScope.modelData
            source: Persistent.persistence.currentWallpaper
        }
    }
}
