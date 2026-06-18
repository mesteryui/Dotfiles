import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Services.Pipewire
import qs.Core

PercentageOSD {
    id: root

    property bool ready: false
    
    // Rastreador para asegurar que el objeto no sea recolectado y sea estable
    PwObjectTracker {
        id: tracker
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null

    Connections {
        target: root.audio
        ignoreUnknownSignals: true // Por si el objeto es nulo momentáneamente

        function onVolumeChanged() { 
            if (root.ready) root.show() 
        }
        function onMutedChanged() { 
            if (root.ready) root.show() 
        }
    }

    Timer {
        id: readyTimer
        interval: 1000
        running: true
        repeat: false
        onTriggered: root.ready = true
    }
    
    percentage: root.audio ? root.audio.volume : 0
    icon: {
        if (!root.audio) return "volume_off"
        if (root.audio.muted) return "volume_off"
        const vol = root.audio.volume
        if (vol > 0.6) return "volume_up"
        if (vol > 0.2) return "volume_down"
        return "volume_mute"
    }
}
