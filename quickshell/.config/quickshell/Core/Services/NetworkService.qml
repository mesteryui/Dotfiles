pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Networking
import qs.Core.Modules

Singleton {
    id: root

    readonly property var currentDevice: {
        // 1. Si el módulo de red aún no está listo, devolvemos null de inmediato.
        if (!Networking.devices)
            return null;

        // 2. Extraemos la lista de forma segura (asumiendo que uses .values o la lista directa)
        const deviceList = Networking.devices.values;

        // 3. Si la lista está vacía, devolvemos null.
        if (!deviceList || deviceList.length === 0)
            return null;

        // 4. Buscamos el conectado, o caemos en el primero de la lista.
        return deviceList.find(e => e.state === ConnectionState.Connected) ?? deviceList[0];
    }

    readonly property var currentNetwork: currentDevice?.networks.values.find(e => e.state === ConnectionState.Connected) ?? null

    // Nombre de la red activa (SSID en WiFi, "Ethernet" en cable, "" si desconectado)
    readonly property string networkName: {
        if (root.currentDevice === null)
            return "";
        if (currentDevice.type === DeviceType.Wired)
            return "Ethernet";
        return root.currentDevice.name ?? "";
    }

    // Icono Material Symbols según estado/señal
    readonly property string materialIconBySignal: {
        if (root.currentDevice === null)
            return "signal_wifi_off";
        if (Networking.connectivity === NetworkConnectivity.None)
            return "signal_wifi_off";
        if (currentDevice.type === DeviceType.Wired)
            return "settings_ethernet";
        const signal = root.currentNetwork?.signalStrength;
        return Icons.getNetworkIcon(Math.floor(signal * 100));
    }
}
