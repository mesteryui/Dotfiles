import QtQuick
import Quickshell

// Usamos Scope para agrupar lógicamente los OSDs sin añadir peso visual extra
Scope {
    id: osdManager

    // --- Carga Inmediata ---
    // Componentes ligeros o de uso crítico instantáneo.
    // Como heredan de BaseOSD, ya saben exactamente en qué pantalla aparecer gracias a 'focusedScreen'.
    VolumeOSD {}
    BrightnessOSD {}
    MicOSD {}

    SpecialKeysOSD {}

    GameModeOSD {}

    BatteryOSD {}
}
