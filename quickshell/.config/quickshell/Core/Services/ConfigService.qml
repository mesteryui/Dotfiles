pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: root
    property alias configs: jsonAdapter


    Timer {
        id: fileReloader
        interval: 100
        repeat: false
        onTriggered: {
            fileManagment.reload()
        }
    }
    Timer {
        id: fileWriter
        interval: 100
        repeat: false
        onTriggered: {
            fileManagment.writeAdapter()
        }
    }
    
    FileView {
        id: fileManagment
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: fileReloader.restart()
        onAdapterUpdated: fileWriter.restart()
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
        property bool darkMode: true
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
