pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property string splashPhrase: ""

    property list<string> splashPrases: ["Advance with clarity. The path is built by motion.",
        "Direction over speed. Let precision guide the core.", "Carbon foundations, golden execution.",
        "Stripped of clutter. Focused on the horizon.", "Every trace leaves a path. Make yours deliberate.",
        "Quiet the interface. Amplify the intent."]

    enum Modes {
        HYPR,
        CUSTOM
    }

    property int mode: RandomPhraseses.Modes.CUSTOM

    Connections {
        target: HyprlandIpc
        ignoreUnknownSignals: true

        function onReplyReceived(command, reply) {
            if (command !== "splash")
                return;
            root.splashPhrase = reply.trim();
        }

        function onRequestFailed(command, reason) {
            if (command !== "splash")
                return;
            console.warn("[RandomPhrases] splash falló:", reason);
        }
    }

    function obtainPhrase() {
        if (mode === RandomPhraseses.Modes.HYPR) {
            // Mismos bytes que `hyprctl splash`, por el socket y sin fork.
            // Si se llama dos veces seguidas, HyprlandIpc encola; gana la última.
            HyprlandIpc.send("splash");
        } else if (mode === RandomPhraseses.Modes.CUSTOM) {
            root.splashPhrase = root.splashPrases[Math.floor(Math.random() * root.splashPrases.length)];
        }
    }

    Component.onCompleted: root.obtainPhrase()
}
