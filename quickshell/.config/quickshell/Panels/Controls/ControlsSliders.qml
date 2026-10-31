// ControlsSliders — volumen y brillo (monitor enfocado, estilo end-4/caelestia).
// Extraído de PanelWithControlsContent.qml. `host` es la raíz del
// contenido; focusAbove/focusBelow encadenan el foco con cabecera y toggles.
// Un solo slider de brillo atado a BrightnessService.focusedMonitor: sigue
// el foco de Hyprland y evita apilar un slider por pantalla.
pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Core.Services.Brightness as Brightness
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

    // Atajo reactivo al monitor enfocado (null mientras detecta).
    readonly property var focused: Brightness.BrightnessService.focusedMonitor
    readonly property bool multiMonitor: Brightness.BrightnessService.monitors.length > 1

    spacing: Appearance.spacing.small

    // Volumen
    ControlSlider {
        id: volumeSliderItem
        Layout.fillWidth: true

        icon: Services.AudioService.materialIcon
        value: Services.AudioService.volume ?? 0
        accentColor: Appearance.md3.primary
        accessibleName: "Volumen"
        keyboardMode: root.host.keyboardMode
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
        Keys.onPressed: root.host.keyboardMode = true
        Keys.onUpPressed: {
            if (root.focusAbove)
                root.focusAbove.forceActiveFocus();
        }
        Keys.onDownPressed: {
            if (brightnessSliderItem.visible)
                brightnessSliderItem.forceActiveFocus();
            else if (root.focusBelow)
                root.focusBelow.forceActiveFocus();
        }
        onActiveFocusChanged: {
            if (activeFocus)
                root.host.ensureVisible(volumeSliderItem);
        }
        onMouseUsed: root.host.keyboardMode = false
    }

    // Brillo del monitor enfocado: sigue Hyprland.focusedMonitor.
    // Con 2+ pantallas el nombre aclara cuál se está moviendo.
    ControlSlider {
        id: brightnessSliderItem
        Layout.fillWidth: true

        visible: root.focused !== null && root.focused.supported && root.focused.ready
        // Roundtrip lento (spawn + sysfs/DDC): eco local al arrastrar.
        liveEcho: true
        icon: {
            const b = root.focused?.brightness ?? 0;
            if (b > 0.6)
                return "brightness_high";
            if (b > 0.3)
                return "brightness_medium";
            return "brightness_low";
        }
        value: root.focused?.brightness ?? 0
        accentColor: Appearance.md3.tertiary
        accessibleName: root.multiMonitor && root.focused ? "Brillo " + root.focused.screenName : "Brillo"
        keyboardMode: root.host.keyboardMode
        onMoved: val => {
            if (root.focused)
                root.focused.setBrightness(val);
        }
        Keys.onPressed: root.host.keyboardMode = true
        Keys.onUpPressed: volumeSliderItem.forceActiveFocus()
        Keys.onDownPressed: {
            if (root.focusBelow)
                root.focusBelow.forceActiveFocus();
        }
        onActiveFocusChanged: {
            if (activeFocus)
                root.host.ensureVisible(brightnessSliderItem);
        }
        onMouseUsed: root.host.keyboardMode = false
    }
}
