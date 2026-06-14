import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Services.Pipewire

PercentageOSD {
    id: root
    
    Connections {
        target: Pipewire.defaultAudioSink?.audio
        function onVolumeChanged() {
            root.show()
        }
        function onMutedChanged() {
            root.show()
        }
    }
    
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    
    percentage: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    icon: {
        if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio) return "󰝟"
        if (Pipewire.defaultAudioSink.audio.muted) return "󰝟"
        const vol = Pipewire.defaultAudioSink.audio.volume
        if (vol > 0.6) return "󰕾"
        if (vol > 0.2) return "󰖀"
        return "󰕿"
    }
}
