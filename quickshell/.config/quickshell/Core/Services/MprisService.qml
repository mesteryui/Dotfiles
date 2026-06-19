// --- MprisService ---
// Singleton que gestiona el player MPRIS activo.
// Expone metadatos cacheados (arte, duración) y controles de reproducción.
pragma Singleton

import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property bool hasPlayer: currentMprisPlayer !== null
    readonly property bool isPlaying: hasPlayer
        && currentMprisPlayer.playbackState === MprisPlaybackState.Playing

    
    property MprisPlayer currentMprisPlayer: {
        const players = Mpris.players.values;
        return players.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? players.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? players[0]
            ?? null;
    }

    // ── Metadatos cacheados ───────────────────────────────────

    
    property alias lastTrackArtUrl: persistent.lastTrackArtUrl

    PersistentProperties {
        id: persistent
        property string lastTrackArtUrl: ""
    }

    // Duración: binding reactivo, se reevalúa solo cuando cambia el player
    // o cuando el player emite lengthChanged. Los componentes la leen de aquí
    // en lugar de escuchar onLengthChanged ellos mismos.
    readonly property real trackLength: currentMprisPlayer?.length ?? 0

    // ── Reacciones a cambio de player ─────────────────────────
    onCurrentMprisPlayerChanged: updateLastTrack()

    Connections {
        target: root.currentMprisPlayer
        enabled: root.currentMprisPlayer !== null

        function onTrackArtUrlChanged(): void {
            root.updateLastTrack()
        }
    }

    function updateLastTrack(): void {
        const url = root.currentMprisPlayer?.trackArtUrl ?? "";
        if (url !== "")
            root.lastTrackArtUrl = url;
    }

    // ── Controles ─────────────────────────────────────────────
    function togglePlaying(): void {
        if (currentMprisPlayer?.canTogglePlaying)
            currentMprisPlayer.togglePlaying();
    }

    function previousTrack(): void {
        currentMprisPlayer?.previous();
    }

    function nextTrack(): void {
        if (!currentMprisPlayer) return;

        if (currentMprisPlayer.canGoNext) {
            currentMprisPlayer.next();
        } else {
            // Fallback via playerctl para players que no implementan canGoNext
            goNext.command = ["playerctl", "next", "--player", currentMprisPlayer.dbusName];
            goNext.running = true;
        }
    }

    // ── Seek ──────────────────────────────────────────────────
    // Centralizado aquí para que cualquier componente pueda llamarlo
    // sin tocar el player directamente.
    function seekTo(positionMicroseconds: real): void {
        if (currentMprisPlayer)
            currentMprisPlayer.position = positionMicroseconds;
    }

    // ── Procesos internos ─────────────────────────────────────
    Process { id: goNext }
}