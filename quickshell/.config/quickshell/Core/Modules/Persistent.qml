pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Modules

Singleton {
    id: root

    property alias persistence: persitenceStates
    property bool ready: false

    Timer {
        id: fileReloadTimer

        interval: 100
        repeat: false
        onTriggered: {
            fileManagment.reload();
        }
    }

    Timer {
        id: fileWriteTimer

        interval: 100
        repeat: false
        onTriggered: {
            fileManagment.writeAdapter();
        }
    }

    FileView {
        id: fileManagment

        watchChanges: true
        path: Directories.state + "/quickshell/persistence.json"
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            console.log("Failed to load persistent states file:", error);
            if (error == FileViewError.FileNotFound) {
                fileWriteTimer.restart();
            }
        }

        JsonAdapter {
            id: persitenceStates

            property string currentWallpaper: ""
        }
    }
}
