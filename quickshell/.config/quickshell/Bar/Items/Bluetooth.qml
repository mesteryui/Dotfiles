import qs.Primitives
import qs.Core
import qs.Core.Services as Services
import qs.Panels.Bluetooth
import QtQuick

BarItem {
    id: root

    clickable: true
    onClicked: btPanel.toggle()

    BarPopup {
        id: btPanel

        anchorItem: root
        hovered: root.hovered
        pressed: root.pressed
        component: BluetoothPanel {
            id: panel
        }
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
