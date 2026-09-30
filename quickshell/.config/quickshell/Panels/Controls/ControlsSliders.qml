// ControlsSliders — volumen y brillo.
// Extraído de PanelWithControlsContent.qml. `host` es la raíz del
// contenido; focusAbove/focusBelow encadenan el foco con cabecera y toggles.
import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var host
    property Item focusAbove
    property Item focusBelow
    property alias volumeSlider: volumeSliderItem
    property alias brightnessSlider: brightnessSliderItem

    spacing: Appearance.spacing.s

    // Volumen
    ControlSlider {
        id: volumeSliderItem
        Layout.fillWidth: true
        iconName: Services.AudioService.materialIcon
        value: Services.AudioService.volume ?? 0
        accentColor: Appearance.md3.primary
        accessibleName: "Volumen"
        keyboardMode: host.keyboardMode
        onMoved: val => {
            if (Services.AudioService.audio) {
                Services.AudioService.audio.volume = val;
            }
        }
        onIconClicked: {
            if (Services.AudioService.audio) {
                Services.AudioService.audio.muted = !Services.AudioService.audio.muted;
            }
        }
        Keys.onPressed: host.keyboardMode = true
        Keys.onUpPressed: powerButton.forceActiveFocus()
        Keys.onDownPressed: {
            if (brightnessSliderItem.visible)
                brightnessSliderItem.forceActiveFocus();
            else
                (focusBelow ? focusBelow.forceActiveFocus() : undefined);
        }
        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(volumeSliderItem);
        }
        onMouseUsed: host.keyboardMode = false
    }

    // Brillo
    ControlSlider {
        id: brightnessSliderItem
        Layout.fillWidth: true
        visible: Services.BrightnessService.ready
        // Roundtrip lento (spawn + sysfs): eco local al arrastrar.
        liveEcho: true
        iconName: {
            const b = Services.BrightnessService.brightness;
            if (b > 0.6)
                return "brightness_high";
            if (b > 0.3)
                return "brightness_medium";
            return "brightness_low";
        }
        value: Services.BrightnessService.brightness
        accentColor: Appearance.md3.tertiary
        accessibleName: "Brillo"
        keyboardMode: host.keyboardMode
        onMoved: val => Services.BrightnessService.setBrightness(val)
        Keys.onPressed: host.keyboardMode = true
        Keys.onUpPressed: volumeSliderItem.forceActiveFocus()
        Keys.onDownPressed: (focusBelow ? focusBelow.forceActiveFocus() : undefined)
        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(brightnessSliderItem);
        }
        onMouseUsed: host.keyboardMode = false
    }
}
