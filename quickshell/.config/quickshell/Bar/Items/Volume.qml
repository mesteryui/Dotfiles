import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../Core"
import "../../Core/Services" as Services
import "../../Components"
import "."

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

        MaterialIcon {
            id: volumeIcon
            size: 20
            color: Colors.on_surface
            icon: {
                if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio) return "volume_off"
                if (Pipewire.defaultAudioSink.audio.muted) return "volume_off"
                const vol = Pipewire.defaultAudioSink.audio.volume
                if (vol > 0.6) return "volume_up"
                if (vol > 0.2) return "volume_down"
                return "volume_mute"
            }
        }

        Text {
            id: volumeLabel
            anchors.verticalCenter: parent.verticalCenter
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