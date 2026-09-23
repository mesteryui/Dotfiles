pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Modules

Singleton {
    id: root

    property alias configs: jsonAdapter
    property bool ready: false

    readonly property string configDir: Directories.config + "/shinro"
    readonly property string configFile: configDir + "/config.json"

    // load() es solo excusa para instanciar el singleton (ver shell.qml).
    function load() {
    }

    // Debounce igual que Persistent: evita bucles escritura->watch->recarga.
    Timer {
        id: reloadTimer

        interval: 100
        repeat: false
        onTriggered: fileManagment.reload()
    }

    Timer {
        id: writeTimer

        interval: 100
        repeat: false
        onTriggered: fileManagment.writeAdapter()
    }

    FileView {
        id: fileManagment

        path: root.configFile
        blockLoading: true
        watchChanges: true
        printErrors: true
        atomicWrites: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: {
            root.ready = true;
        }
        onLoadFailed: error => {
            // Primera ejecución: el archivo no existe. Al volcar el
            // adapter, FileView crea el archivo y los directorios padre.
            if (error == FileViewError.FileNotFound) {
                writeTimer.restart();
            }
        }

        JsonAdapter {
            id: jsonAdapter

            property string language: "auto"
            property Bar bar: Bar {}
            property Weather weather: Weather {}
            property Notifications notifications: Notifications {}
            property Updates updates: Updates {}
            property LockScreen lockscreen: LockScreen {}
            property NightLight nightLight: NightLight {}
            property Appearance appearance: Appearance {}
        }
    }

    component LockScreen: JsonObject {
        property real blurLevel: 1.3
        property bool useWallpaper: true
    }
    component Weather: JsonObject {
        property bool autoLocation: true
        property string city: "Vigo"
        property int reloadTime: 10
    }
    component NightLight: JsonObject {
        property int temperature: 3000
        property int gamma: 100
    }
    component Appearance: JsonObject {
        property bool darkMode: true
        property string fontSans: "Google Sans Flex"
        property string monospace: "JetBrains Mono Nerd Font"
        property string reading: "Google Sans Flex"
        property string expressive: "Google Sans Flex"
        property Matugen matugen: Matugen {}
    }
    component Bar: JsonObject {
        property string position: "top"
        property int height: 36
        property string workspaceButtonType: "numbers"
        property bool floating: true
        property string barType: "floating" // Floating, full_hug, partial_hug, no_floating
    }
    component Notifications: JsonObject {
        property int timeout: 5
    }
    component Updates: JsonObject {
        property int countTime: 60
        property string command: "topgrade"
    }
    component Matugen: JsonObject {
        property string type: "scheme-tonal-spot"
    }
}
