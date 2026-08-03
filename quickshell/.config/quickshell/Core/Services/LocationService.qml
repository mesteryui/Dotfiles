pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: root
    property real latitud: 0.0
    property real longitud: 0.0

    function obtainLocation() {
        locationObtainer.running = true
    }


    Process {
        id: locationObtainer
        command: ["python", Quickshell.shellPath("scripts/location.py")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text)
                    root.latitud = parsed.latitud
                    root.longitud = parsed.longitud
                } catch(e) {
                    console.log("ERROR parsing Location output",e);
                }
            }
        }
    }
}