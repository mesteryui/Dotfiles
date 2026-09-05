import qs.Primitives
import qs.Core
import qs.Core.Services as Services
import qs.Core.Modules
import QtQuick
import Quickshell

BarItem {
    clickable: true
    onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "bluetui"])

    MaterialIcon {
        color: Appearance.md3.on_surface
        anchors.centerIn: parent
        size: Appearance.font.pixelSize.larger
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
