import QtQuick
import Quickshell
import qs.Primitives
import qs.Core
import qs.Core.Services as Services

BarItem {
    clickable: true
    onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "bluetui"])
    MaterialIcon {
        color: Colors.md3.on_surface
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
