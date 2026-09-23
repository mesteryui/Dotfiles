import qs.Primitives
import qs.Core
import qs.Core.Services as Services
import qs.Core.Modules
import qs.Panels.Bluetooth
import QtQuick
import Quickshell

BarItem {
    id: root

    clickable: true
    onClicked: btPanel.visible = !btPanel.visible

    BluetoothPanel {
        id: btPanel
    }

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
