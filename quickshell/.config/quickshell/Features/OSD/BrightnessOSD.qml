import qs.Core.Services as Services
import QtQuick

PercentageOSD {
    id: root
    type: "brightness"
    percentage: Services.BrightnessService.brightness
    icon: {
        const b = Services.BrightnessService.brightness;
        if (b < 0.33)
            return "brightness_low";
        if (b < 0.66)
            return "brightness_medium";
        return "brightness_high";
    }

    Connections {
        target: Services.BrightnessService
        function onBrightnessChanged() {    // ← brightness en lugar de rawValue
            if (Services.BrightnessService.ready) {
                root.show();
            }
        }
    }
}
