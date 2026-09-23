import qs.Core.Services
import QtQuick
import M3Shapes

PercentageOSD {
    id: root

    type: "volume"

    property bool ready: false

    Connections {
        target: AudioService.audio
        ignoreUnknownSignals: true // Por si el objeto es nulo momentáneamente

        function onVolumeChanged() {
            if (root.ready)
                root.show();
        }

        function onMutedChanged() {
            if (root.ready)
                root.show();
        }
    }

    Timer {
        id: readyTimer

        interval: 1000
        running: true
        repeat: false
        onTriggered: root.ready = true
    }

    percentage: AudioService.volume

    icon: AudioService.materialIcon

    // Morph continuo: Circle → Cookie9Sided (energía sonora).
    // Muteado: ClamShell (boca cerrada) + error.
    continuousMorph: true
    soundMorphFrom: MaterialShape.Circle
    soundMorphTo: MaterialShape.Cookie9Sided

    alert: AudioService.muted
}
