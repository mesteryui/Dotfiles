pragma Singleton

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias persistence: persistenceStates
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
            console.info("Failed to load persistent states file:", error);
            if (error == FileViewError.FileNotFound) {
                fileWriteTimer.restart();
            }
        }

        JsonAdapter {
            id: persistenceStates

            property string currentWallpaper: ""
            // IDs (.desktop) de apps fijadas en el launcher, en orden.
            property list<string> pinnedApps: []
        }
    }
}
