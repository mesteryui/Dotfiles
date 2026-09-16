import QtQuick
import qs.Core.Services

PercentageOSD {
    id: root

    // Define el tipo para el namespace del WlrLayershell (se convertirá en "quickshell:osd-mic")
    type: "mic"

    property bool ready: false

    Timer {
        id: readyTimer

        interval: 1000
        running: true
        repeat: false
        onTriggered: root.ready = true
    }

    // Enlazamos las propiedades requeridas por PercentageOSD con las del AudioService
    percentage: AudioService.micVolume
    icon: AudioService.micMaterialIcon

    // Escuchamos los cambios en el servicio de audio para mostrar el OSD
    Connections {
        target: AudioService
        ignoreUnknownSignals: true

        // Se dispara al cambiar el volumen del micrófono
        function onMicVolumeChanged() {
            if (root.ready)
                root.show();
        }

        // Se dispara al silenciar/desilenciar el micrófono
        function onMicMutedChanged() {
            if (root.ready)
                root.show();
        }
    }
}
