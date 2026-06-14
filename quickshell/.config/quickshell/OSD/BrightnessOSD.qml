import "../Services" as Services
import QtQuick
import Quickshell

PercentageOSD {
    id: root
    percentage: Services.BrightnessService.brightness
    icon: {
        const b = Services.BrightnessService.brightness
        if (b < 0.33) return "󰃞"
        if (b < 0.66) return "󰃟"
        return "󰃠"
    }

    Connections {
        target: Services.BrightnessService
        function onBrightnessChanged() {    // ← brightness en lugar de rawValue
            if (Services.BrightnessService.ready) {
                root.show()
            }
        }
    }
}