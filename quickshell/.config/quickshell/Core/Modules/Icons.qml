pragma Singleton

import Quickshell

Singleton {
    id: root

    function getNetworkIcon(strength: int): string {
        if (strength >= 80)
            return "network_wifi";
        if (strength >= 60)
            return "network_wifi_3_bar";
        if (strength >= 40)
            return "network_wifi_2_bar";
        if (strength >= 20)
            return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    function getWeatherIcon(code, isDay = true): string {
        const icon = weatherIconMap[parseInt(code, 10)];

        // Si el código no existe en el diccionario, devolvemos el valor por defecto
        if (!icon)
            return "device_thermostat";

        // Si es un array (códigos 0, 1, 2), usamos el valor booleano convertido a número.
        // Number(false) es 0 (índice de noche), Number(true) es 1 (índice de día).
        return Array.isArray(icon) ? icon[Number(isDay)] : icon;
    }

    // Memoización por appId: DesktopEntries.heuristicLookup + iconPath en
    // cada re-evaluación del delegado era el coste dominante del switcher.
    property var _appIconCache: ({})

    function getAppIcon(name: string, fallback: string): string {
        const key = (name || "") + "|" + (fallback || "");
        const hit = root._appIconCache[key];
        if (hit !== undefined)
            return hit;
        const icon = DesktopEntries.heuristicLookup(name)?.icon;
        const resolved = fallback !== undefined ? Quickshell.iconPath(icon, fallback) : Quickshell.iconPath(icon);
        // Capado blando: si alguna vez hay cientos de appIds distintos, se
        // reinicia en vez de crecer sin cota.
        if (Object.keys(root._appIconCache).length > 400)
            root._appIconCache = ({});
        root._appIconCache[key] = resolved;
        return resolved;
    }

    function getBluetoothDeviceMaterialSymbol(systemIconName: string): string {
        if (systemIconName.includes("headset") || systemIconName.includes("headphones"))
            return "headphones";
        if (systemIconName.includes("audio"))
            return "speaker";
        if (systemIconName.includes("phone"))
            return "smartphone";
        if (systemIconName.includes("mouse"))
            return "mouse";
        if (systemIconName.includes("keyboard"))
            return "keyboard";
        return "bluetooth";
    }
    function getBatteryIcon(percentage: real, charging = false): string {
        if (percentage === 1)
            return charging ? "battery_charging_full" : "battery_full";
        let level = Math.floor(percentage * 7);
        if (charging && (level === 4 || level === 1))
            level--;
        return charging ? `battery_charging_${(level + 3) * 10}` : `battery_${level}_bar`;
    }

    readonly property var weatherIconMap: ({
            0: ["bedtime", "wb_sunny"],
            1: ["nights_stay", "partly_cloudy_day"],
            2: ["nights_stay", "partly_cloudy_day"],
            3: "cloud",
            45: "foggy",
            48: "foggy",
            51: "rainy",
            53: "rainy",
            55: "rainy",
            56: "rainy",
            57: "rainy",
            61: "rainy",
            63: "rainy",
            65: "rainy",
            66: "rainy",
            67: "rainy",
            80: "rainy",
            81: "rainy",
            82: "rainy",
            71: "ac_unit",
            73: "ac_unit",
            75: "ac_unit",
            77: "ac_unit",
            85: "ac_unit",
            86: "ac_unit",
            95: "thunderstorm",
            96: "thunderstorm",
            99: "thunderstorm"
        })
}
