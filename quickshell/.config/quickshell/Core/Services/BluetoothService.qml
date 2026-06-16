pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property BluetoothAdapter currentAdapter: Bluetooth.defaultAdapter

    // Conveniencias — simplifican los consumidores
    readonly property bool available: currentAdapter !== null
    readonly property bool enabled: available
        && currentAdapter.state === BluetoothAdapterState.Enabled

    // Propiedad intermedia para que el binding a .state de cada device funcione
    readonly property list<BluetoothDevice> devices: currentAdapter?.devices.values ?? []

    readonly property BluetoothDevice connectedDevice: {
        for (const device of devices) {
            if (device.state === BluetoothDeviceState.Connected)
                return device
        }
        return null
    }

    readonly property bool isConnected: connectedDevice !== null
}