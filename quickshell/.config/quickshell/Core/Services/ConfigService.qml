pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: root
    property alias configs: jsonAdapter

    FileView {
        id: fileManagment
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: jsonAdapter
            property string language: Qt.locale().name
            property Bar bar: Bar {}
            property Notifications notifications: Notifications {}
            property Updates updates: Updates {}
            property Appearence appearence: Appearence {}
        }
    }
    component Appearence: JsonObject {
        property string fontSans: "Google Sans Flex"
        property string monospace: "JetBrains Mono Nerd Font"
        property Matugen matugen: Matugen {}
    }
    component Bar: JsonObject {
        property string position: "top"
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
