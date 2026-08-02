pragma Singleton
import Quickshell.Services.UPower
import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var displayDevice: UPower.displayDevice
        readonly property var percentage: {
            const p = displayDevice?.percentage ?? 0
            return Math.round(p * 100)
        }
        readonly property string materialIcon: {
            const device = displayDevice;
            if (!device) return "battery_unknown";

            const p = device.percentage;
            const isCharging = device.state === UPowerDeviceState.Charging;

            if (isCharging)
            {
                if (p > 0.9) return "battery_charging_full";
                if (p > 0.75) return "battery_charging_80";
                if (p > 0.55) return "battery_charging_60";
                if (p > 0.4) return "battery_charging_50";
                if (p > 0.25) return "battery_charging_30";
                return "battery_charging_20";
            }

            if (p > 0.9) return "battery_full";
            if (p > 0.7) return "battery_6_bar";
            if (p > 0.5) return "battery_4_bar";
            if (p > 0.3) return "battery_3_bar";
            if (p > 0.15) return "battery_1_bar";
            return "battery_0_bar";
        }
        readonly property var profile: PowerProfiles.profile
        function changeProfile(newProfile) {
            PowerProfiles.profile = newProfile
        }
    }