pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string splashPhrase: ""

    enum Modes {
        HYPR,
        CUSTOM
    }

    property int mode: RandomPhraseses.Modes.HYPR

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
                root.splashPhrase = ""
            }
        }
    }

    Component.onCompleted: root.obtainPhrase()
}
