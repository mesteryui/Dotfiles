pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias configs: jsonAdapter

    function load() {
    }

    FileView {
        id: fileManagment

        path: Quickshell.shellPath("config.json")
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: jsonAdapter

            property string language: Qt.locale().name
            property Bar bar: Bar {}
            property Weather weather: Weather {}
            property Notifications notifications: Notifications {}
            property Updates updates: Updates {}
            property LockScreen lockscreen: LockScreen {}
            property NightLight nightLight: NightLight {}
            property Appearence appearence: Appearence {}
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
    component Appearence: JsonObject {
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
