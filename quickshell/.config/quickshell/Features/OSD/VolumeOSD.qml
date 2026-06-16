import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Services.Pipewire
import "."

PercentageOSD {
    id: root
    
    Connections {
        target: Pipewire.defaultAudioSink?.audio
        function onVolumeChanged() { root.show() }
        function onMutedChanged() { root.show() }
    }
    
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    
    percentage: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    icon: {
        if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio) return "volume_off"
        if (Pipewire.defaultAudioSink.audio.muted) return "volume_off"
        const vol = Pipewire.defaultAudioSink.audio.volume
        if (vol > 0.6) return "volume_up"
        if (vol > 0.2) return "volume_down"
        return "volume_mute"
    }
}
