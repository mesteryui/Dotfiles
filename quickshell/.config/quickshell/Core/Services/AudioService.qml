// --- AudioService ---
// Singleton de audio vía Pipewire: expone el sink (salida) y el source (micrófono)
// por defecto, sus niveles/mute, y la lista de dispositivos disponibles para poder
// cambiar de altavoz o de micrófono desde la UI (p. ej. AudioPopupWindow).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // ── Salida (altavoces) ───────────────────────────────────
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink ? root.sink.audio : null
    readonly property real volume: root.audio ? root.audio.volume : 0
    readonly property bool muted: root.audio ? root.audio.muted : false

    // ── Entrada (micrófono) ──────────────────────────────────
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var micAudio: root.source ? root.source.audio : null
    readonly property real micVolume: root.micAudio ? root.micAudio.volume : 0
    readonly property bool micMuted: root.micAudio ? root.micAudio.muted : false

    // Solo hace falta enlazar (bind) los nodos que están activos como default:
    // sus propiedades de audio (volume/muted) no son válidas hasta que se
    // registran aquí vía PwObjectTracker.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }

    // ── Dispositivos disponibles (para el selector de altavoz/micrófono) ──
    // .values es reactivo (valuesChanged) así que esta lista se actualiza sola
    // cuando se conecta o desconecta un dispositivo.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSink)

    readonly property var sources: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSource)

    function deviceLabel(node) {
        if (!node)
            return "";
        return node.description || node.nickname || node.name;
    }

    // ── Iconografía ───────────────────────────────────────────
    readonly property string materialIcon: {
        if (!root.audio || root.muted)
            return "volume_off";
        const vol = root.volume;
        if (vol > 0.6)
            return "volume_up";
        if (vol > 0.2)
            return "volume_down";
        return "volume_mute";
    }

    readonly property string micMaterialIcon: (!root.micAudio || root.micMuted) ? "mic_off" : "mic"

    // ── Acciones ──────────────────────────────────────────────
    function setVolume(val) {
        if (root.audio)
            root.audio.volume = Math.max(0, Math.min(1, val));
    }

    function toggleMuted() {
        if (root.audio)
            root.audio.muted = !root.audio.muted;
    }

    function setMicVolume(val) {
        if (root.micAudio)
            root.micAudio.volume = Math.max(0, Math.min(1, val));
    }

    function toggleMicMuted() {
        if (root.micAudio)
            root.micAudio.muted = !root.micAudio.muted;
    }

    function setSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
}
