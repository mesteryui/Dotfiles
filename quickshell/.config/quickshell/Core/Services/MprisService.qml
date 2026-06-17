pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property bool hasPlayer: currentMprisPlayer !== null
    readonly property bool isPlaying: hasPlayer && currentMprisPlayer.playbackState === MprisPlaybackState.Playing

    property MprisPlayer currentMprisPlayer: {
        const players = Mpris.players.values;
        return players.find(p => p.playbackState === MprisPlaybackState.Playing) ?? players.find(p => p.playbackState === MprisPlaybackState.Paused) ?? players[0] ?? null;
    }
    property string lastTrackArtUrl: ""
    onCurrentMprisPlayerChanged: updateLastTrack()
    function updateLastTrack() {
        const url = root.currentMprisPlayer?.trackArtUrl ?? "";
        if (url !== "")
            root.lastTrackArtUrl = url;
    }
    Component.onCompleted: updateLastTrack()
    Connections {
        target: root.currentMprisPlayer
        enabled: root.currentMprisPlayer !== null
        function onTrackArtUrlChanged(): void {
            root.updateLastTrack()
        }
    }
    function togglePlaying() {
        if (currentMprisPlayer?.canTogglePlaying)
            currentMprisPlayer.togglePlaying();
    }

    function previousTrack() {
        currentMprisPlayer?.previous();
    }

    function nextTrack() {
        if (!currentMprisPlayer) {
            return;
        }
        if (currentMprisPlayer.canGoNext) {
            currentMprisPlayer.next();
        } else {
            goNext.command = ["playerctl", "next", "--player", currentMprisPlayer.dbusName];
            goNext.running = true;
        }
    }
    Process {
        id: goNext
    }
}
