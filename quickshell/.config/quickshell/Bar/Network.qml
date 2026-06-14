import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Networking
import ".."

BarItem {
    id: root
    
    clickable: true
    onClicked: Quickshell.execDetached([
        "xdg-terminal-exec", 
        "--app-id=local.floating", 
        "-e", 
        "impala"
    ])

    IconImage {
        id: networkIcon
        width: 24
        height: 24
        anchors.centerIn: parent
        source: {
            if (Networking.connectivity === NetworkConnectivity.None) {
                return Quickshell.iconPath("network-wireless-disconnected")
            }
            
            const signal = Networking.defaultWifiDevice?.signalStrength ?? 0
            if (signal > 75) return Quickshell.iconPath("network-wireless-signal-excellent");
            if (signal > 50) return Quickshell.iconPath("network-wireless-signal-good");
            if (signal > 25) return Quickshell.iconPath("network-wireless-signal-ok");
            return Quickshell.iconPath("network-wireless-signal-weak");
        }
    }
}
