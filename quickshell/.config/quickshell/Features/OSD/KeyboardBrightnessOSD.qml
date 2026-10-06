import qs.Core.Services.Brightness as Brightness
import QtQuick

PercentageOSD {
    id: root

    type: "kbd_brightness"

    percentage: Brightness.KbdBacklight.brightness
    icon: "keyboard"
    // Pasos discretos ("1 / 3") en vez de porcentaje.
    labelOverride: Brightness.KbdBacklight.rawValue + " / " + Brightness.KbdBacklight.maxValue

    Connections {
        target: Brightness.KbdBacklight

        function onBrightnessChanged() {
            if (Brightness.KbdBacklight.ready && Brightness.KbdBacklight.supported)
                root.show();
        }
    }
}
