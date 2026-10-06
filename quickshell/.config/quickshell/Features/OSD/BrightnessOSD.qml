import qs.Core.Services.Brightness as Brightness
import QtQuick
import M3Shapes

PercentageOSD {
    id: root

    type: "brightness"
    // Morph continuo Sunny→VerySunny (luz). Atado al valor.
    continuousMorph: true
    morphFrom: MaterialShape.Sunny
    morphTo: MaterialShape.VerySunny
    percentage: Brightness.BrightnessService.brightness
    icon: {
        const b = Brightness.BrightnessService.brightness;
        if (b < 0.33)
            return "brightness_low";
        if (b < 0.66)
            return "brightness_medium";
        return "brightness_high";
    }

    Connections {
        target: Brightness.BrightnessService

        function onBrightnessChanged() {    // ← brightness en lugar de rawValue
            if (Brightness.BrightnessService.ready) {
                root.show();
            }
        }
    }
}
