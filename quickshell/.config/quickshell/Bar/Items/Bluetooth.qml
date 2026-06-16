import QtQuick
import Quickshell
import "../../Components"
import "../../Core"
import "../../Core/Services" as Services
import Quickshell.Bluetooth

BarItem {
    clickable: true
    onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "bluetui"])
    MaterialIcon {
        color: Colors.on_surface
        anchors.centerIn: parent
        size: 20
        icon: {
            if (!Services.BluetoothService.available)
                return "bluetooth_disabled";
            if (Services.BluetoothService.isConnected)
                return "bluetooth_connected";
            if (Services.BluetoothService.enabled)
                return "bluetooth";
            return "bluetooth_disabled";
        }
    }
}
