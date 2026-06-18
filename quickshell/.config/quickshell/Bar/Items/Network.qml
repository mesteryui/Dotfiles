import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Networking
import qs.Core
import qs.Components

BarItem {
    id: root
    
    clickable: true
    onClicked: Quickshell.execDetached([
        "xdg-terminal-exec", 
        "--app-id=local.floating", 
        "-e", 
        "impala"
    ])

    MaterialIcon {
        id: networkIcon
        anchors.centerIn: parent
        size: 20
        color: Colors.md3.on_surface
        icon: {
            // 1. Manejo explícito de Ethernet
            if (Networking.connectivity === NetworkConnectivity.Wired) {
                return "settings_ethernet"
            }
            
            if (Networking.connectivity === NetworkConnectivity.None) {
                return "signal_wifi_off"
            }
            
            const signal = Networking.defaultWifiDevice?.signalStrength ?? 0
            if (signal > 75) return "network_wifi_4_bar";
            if (signal > 50) return "network_wifi_3_bar";
            if (signal > 25) return "network_wifi_2_bar";
            return "network_wifi_1_bar";

        }
    }
}
