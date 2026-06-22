pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Services.Pipewire

Singleton {
    id: root

    PwObjectTracker {
        id: tracker
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null

    readonly property string materialIcon: {
        if (!root.audio) return "volume_off"
        if (root.audio.muted) return "volume_off"
        const vol = root.audio.volume
        if (vol > 0.6) return "volume_up"
        if (vol > 0.2) return "volume_down"
        return "volume_mute"
    }
    readonly property var volume: root.audio ? root.audio.volume : 0
}