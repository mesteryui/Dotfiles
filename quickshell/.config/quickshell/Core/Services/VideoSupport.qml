pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Disponibilidad de fondos animados (vídeo).
// Prueba la carga del reproductor aislado (AnimatedWallpaperPlayer.qml,
// único fichero con `import QtMultimedia`) vía Qt.createComponent: si el
// módulo QtMultimedia falta, el error queda contenido en el Component y la
// shell sigue intacta. Sin soporte, los vídeos ni se listan (ver
// WallpaperService.activeFilters) y cualquier intento de aplicarlos falla con
// error legible en vez de romper nada.
// LAZY a propósito: instanciar el singleton (leer `available`) NO carga
// QtMultimedia; solo `ensureProbed()` lo hace. Así un arranque estático
// nunca mete GStreamer en el proceso.
Singleton {
    id: root

    property bool available: false
    property bool probed: false
    // La sonda es asíncrona (Component puede tardar un frame): entre
    // ensureProbed() y el finish no se sabe si hay soporte. `settled`
    // distingue "aún sin saber" de "confirmado que no hay".
    property bool settled: false

    // Sonda LAZY: ya no corre en onCompleted para no cargar QtMultimedia
    // en arranques estáticos. La llaman solo quien necesita vídeo:
    // WallpaperLayerScreen (fondo vídeo), WallpaperMenuContent (listar
    // vídeos) y WallpaperService.applyVideo (intención explícita).
    // Idempotente: la segunda llamada es no-op.
    function ensureProbed() {
        root.probe();
    }

    function probe() {
        if (root.probed)
            return;
        root.probed = true;
        let comp = null;
        try {
            comp = Qt.createComponent(Qt.resolvedUrl("../../Panels/Wallpaper/AnimatedWallpaperPlayer.qml"));
        } catch (e) {
            console.warn("[Video] sin soporte QtMultimedia (" + e + "): solo fondos estáticos");
            return;
        }
        if (!comp) {
            console.warn("[Video] sin soporte QtMultimedia: solo fondos estáticos");
            return;
        }
        const finish = () => {
            if (comp.status === Component.Ready) {
                root.available = true;
            } else if (comp.status === Component.Error) {
                console.warn("[Video] sin soporte QtMultimedia (" + comp.errorString()
                             + "): solo fondos estáticos");
            }
            root.settled = true;
            comp.statusChanged.disconnect(finish);
            comp.destroy();
        };
        if (comp.status === Component.Ready || comp.status === Component.Error) {
            finish();
        } else {
            comp.statusChanged.connect(finish);
        }
    }
}
