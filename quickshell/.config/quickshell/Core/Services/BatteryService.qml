pragma Singleton

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root
    readonly property var displayDevice: UPower.displayDevice
    readonly property var percentage: {
        const p = displayDevice?.percentage ?? 0;
        return Math.round(p * 100);
    }
    readonly property string materialIcon: {
        const device = displayDevice;
        if (!device)
            return "battery_unknown";
        return Icons.getBatteryIcon(device.percentage, device.state === UPowerDeviceState.Charging);
    }
    readonly property var profile: PowerProfiles.profile

    function changeProfile(newProfile) {
        PowerProfiles.profile = newProfile;
    }
}
