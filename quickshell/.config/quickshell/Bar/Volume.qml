import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import ".."

BarItem {
    id: root

    clickable: true
    onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "wiremix"])

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Row {
        id: volumeLayout
        spacing: 8
        anchors.centerIn: parent

        Text {
            id: volumeIcon
            text: {
                if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio) return "󰝟"
                if (Pipewire.defaultAudioSink.audio.muted) return "󰝟"
                const vol = Pipewire.defaultAudioSink.audio.volume
                if (vol > 0.6) return "󰕾"
                if (vol > 0.2) return "󰖀"
                return "󰕿"
            }
            color: Colors.on_surface
            font.pixelSize: 14
        }

        Text {
            id: volumeLabel
            text: {
                const audio = Pipewire.defaultAudioSink?.audio;
                if (!audio) return "0%";
                return Math.round(audio.volume * 100) + "%";
            }
            color: Colors.on_surface
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }
}