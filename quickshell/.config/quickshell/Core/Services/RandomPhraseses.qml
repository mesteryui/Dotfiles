pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string splashPhrase: ""

    property list<string> splashPrases: ["Advance with clarity. The path is built by motion.", "Direction over speed. Let precision guide the core.", "Carbon foundations, golden execution.", "Stripped of clutter. Focused on the horizon.", "Every trace leaves a path. Make yours deliberate.", "Quiet the interface. Amplify the intent."]

    enum Modes {
        HYPR,
        CUSTOM
    }

    property int mode: RandomPhraseses.Modes.CUSTOM

    Process {
        id: splashProc

        command: ["hyprctl", "splash"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.splashPhrase = text.trim();
            }
        }
    }

    function obtainPhrase() {
        if (mode === RandomPhraseses.Modes.HYPR) {
            if (splashProc.running) {
                splashProc.running = false;
                Qt.callLater(() => splashProc.running = true);
            } else {
                splashProc.running = true;
            }
        } else {
            if (mode === RandomPhraseses.Modes.CUSTOM) {
                root.splashPhrase = root.splashPrases[Math.floor(Math.random() * root.splashPrases.length)];
            }
        }
    }

    Component.onCompleted: root.obtainPhrase()
}
