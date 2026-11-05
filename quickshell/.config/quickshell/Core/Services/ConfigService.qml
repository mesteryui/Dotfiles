pragma Singleton
pragma ComponentBehavior: Bound

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

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
            property Brightness brightness: Brightness {}
        }
    }

    component LockScreen: JsonObject {
        property real blurLevel: 1.3
        property bool useWallpaper: true
    }
    component Brightness: JsonObject {
        // false = teclas/slider van al monitor enfocado (end-4/caelestia).
        property bool syncAll: false
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
        // Deck frost: desenfoque del wallpaper cuando hay ventanas en la
        // workspace activa. Se puede apagar desde Ajustes > Interfaz.
        property bool deckFrost: false
        property real deckFrostStrength: 0.45
        // Por defecto también con batería: el blur solo trabaja al abrir/cerrar
        // ventana, no en reposo. Se puede apagar desde Ajustes > Interfaz.
        property bool deckFrostOnBattery: true
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
        // Modos: "floating" (píldora flotante con márgenes), "full_hug" (adherida
        // con esquinas de pantalla redondeadas), "partial_hug" (adherida con
        // esquinas solo en el lado de la barra), "notch" (barra con
        // esquinas cóncavas en el borde de la pantalla), "no_floating"
        // (adherida cuadrada).
        property string barType: "floating"
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
