import qs.Core
import qs.Core.Services as Services
import QtQuick
import Quickshell.Services.UPower

// "Deck frost" de Ryoku, aislado del wallpaper: decide cuánto desenfocar y
// cuándo. La parte visual vive en WallpaperFrostEffect y se engancha como
// `layer.effect` en WallpaperLayerScreen. Si se borra este objeto y las dos
// líneas `layer` de wallpaperPlane, el fondo sigue funcionando igual.
//
// Ryoku usa 0.45 de base + 0.25 por ventana extra (tope 1.0) y lo apaga con
// vídeo/visualizador en movimiento y con el modo rendimiento. Aquí los
// equivalentes son un fondo de vídeo, GameMode, la pantalla de bloqueo y el
// ajuste de batería.
//
// El blur solo se recalcula cuando la superficie del wallpaper se redibuja:
// con un fondo estático el coste en reposo es 0. El pico está al abrir/cerrar
// ventana (Behavior) y al animar la fuente (crossfade del wallpaper).
QtObject {
    id: root

    // Los rellena WallpaperLayer, una instancia por monitor.
    property int windowsOnWorkspace: 0
    property bool videoActive: false

    readonly property bool enabledByUser: Services.ConfigService.configs.appearance.deckFrost !== false
    readonly property bool allowedOnBattery: Services.ConfigService.configs.appearance.deckFrostOnBattery
                                             !== false
    readonly property bool onBattery: UPower.onBattery

    readonly property real baseStrength: {
        const value = Number(Services.ConfigService.configs.appearance.deckFrostStrength);
        return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0.45;
    }

    // Mismas condiciones que el deck frost de Ryoku, adaptadas a esta shell.
    readonly property bool requested: root.enabledByUser && !root.videoActive && !Services.GameMode.enabled &&
                                      !Services.LockState.locked && (root.allowedOnBattery ||
                                                                     !root.onBattery)
                                      && root.windowsOnWorkspace > 0

    // 0.45 con una ventana, +0.25 por cada extra; MultiEffect.blur va de 0 a
    // 1. El Behavior mantiene la capa encendida mientras baja a 0 para que el
    // cierre no corte el fundido.
    property real blur: root.requested ? Math.min(1, root.baseStrength + 0.25 * (Math.max(1,
                                                                                          root.windowsOnWorkspace)
                                                                                 - 1)) : 0

    readonly property bool active: root.blur > 0.01
    readonly property int blurMax: 24

    Behavior on blur {
        NumberAnimation {
            duration: Appearance.motion.normal
            easing.type: Easing.OutCubic
        }
    }
}
