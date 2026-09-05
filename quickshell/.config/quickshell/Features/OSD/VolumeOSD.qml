import qs.Core.Services
import QtQuick

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
}
