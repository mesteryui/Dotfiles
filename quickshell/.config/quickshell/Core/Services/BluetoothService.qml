pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property BluetoothAdapter currentAdapter: Bluetooth.defaultAdapter ?? null

    // Conveniencias — simplifican los consumidores
    readonly property bool available: currentAdapter !== null
    readonly property bool enabled: available && currentAdapter?.state === BluetoothAdapterState.Enabled

    // Propiedad intermedia para que el binding a .state de cada device funcione
    readonly property list<BluetoothDevice> devices: currentAdapter?.devices.values ?? []

    readonly property BluetoothDevice connectedDevice: devices.find(d => d.state === BluetoothDeviceState.Connected) ?? null

    readonly property bool isConnected: connectedDevice !== null

    // Batería del conectado (-1 sin dato). Tolera escala 0..1 o 0..100.
    readonly property int connectedBatteryPct: {
        const d = connectedDevice;
        if (!d || !d.batteryAvailable)
            return -1;
        const v = d.battery ?? -1;
        if (v < 0)
            return -1;
        return Math.round(v > 1 ? v : v * 100);
    }
}
