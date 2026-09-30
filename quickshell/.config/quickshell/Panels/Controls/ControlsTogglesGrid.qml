// ControlsTogglesGrid — quick settings (WiFi, BT, cafeína, DND, noche, juego).
// Extraído de PanelWithControlsContent.qml. `host` es la raíz del contenido.
import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

GridLayout {
    id: root

    property var host
    property alias wifiToggle: wifiToggleItem
    property alias gameToggle: gameToggleItem

    columns: 2
    rowSpacing: 8
    columnSpacing: 8
    uniformCellWidths: true

    // WiFi
    ControlToggle {
        id: wifiToggleItem
        Layout.fillWidth: true
        iconName: host.wifiEnabled ? "wifi" : "wifi_off"
        label: Services.I18nService.getTranslation("panel.wifi", "WiFi")
        stateText: host.wifiEnabled ? Services.I18nService.getTranslation("panel.connected", "Conectado") : Services.I18nService.getTranslation("panel.disconnected", "Desconectado")
        active: host.wifiEnabled
        enable: Networking.wifiHardwareEnabled
        keyboardMode: host.keyboardMode
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        KeyNavigation.right: btToggle
        Keys.onPressed: host.keyboardMode = true
        Keys.onUpPressed: host.focusAboveToggles()
        Keys.onDownPressed: cafeToggle.forceActiveFocus()
        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(wifiToggleItem);
        }
        onMouseUsed: host.keyboardMode = false
    }

    // Bluetooth
    ControlToggle {
        id: btToggle
        Layout.fillWidth: true
        iconName: host.btEnabled ? "bluetooth" : "bluetooth_disabled"
        label: Services.I18nService.getTranslation("panel.bluetooth", "Bluetooth")
        stateText: !host.btEnabled ? Services.I18nService.getTranslation("panel.off", "Desactivado") : (Services.BluetoothService.connectedBatteryPct >= 0 ? Services.I18nService.getTranslation("panel.on", "Activado") + " · " + Services.BluetoothService.connectedBatteryPct + "%" : Services.I18nService.getTranslation("panel.on", "Activado"))
        active: host.btEnabled
        enable: host.btAdapter !== null
        keyboardMode: host.keyboardMode
        onToggled: {
            if (host.btAdapter)
                host.btAdapter.enabled = !host.btAdapter.enabled;
        }
        KeyNavigation.left: wifiToggleItem
        Keys.onPressed: host.keyboardMode = true
        Keys.onUpPressed: host.focusAboveToggles()
        Keys.onDownPressed: dndToggle.forceActiveFocus()
        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(btToggle);
        }
        onMouseUsed: host.keyboardMode = false
    }

    // Cafeína
    ControlToggle {
        id: cafeToggle
        Layout.fillWidth: true
        iconName: "local_cafe"
        label: Services.I18nService.getTranslation("panel.caffeine", "Cafeína")
        stateText: Services.IdleInhibitedService.inhibited ? Services.I18nService.getTranslation("panel.caffeine_on", "Activada") : Services.I18nService.getTranslation("panel.caffeine_off", "Desactivada")
        active: Services.IdleInhibitedService.inhibited
        keyboardMode: host.keyboardMode
        onToggled: Services.IdleInhibitedService.toggle()
        KeyNavigation.right: dndToggle
        Keys.onPressed: host.keyboardMode = true
        Keys.onUpPressed: wifiToggleItem.forceActiveFocus()
        Keys.onDownPressed: nightToggle.forceActiveFocus()
        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(cafeToggle);
        }
        onMouseUsed: host.keyboardMode = false
    }

    // No Molestar
    ControlToggle {
        id: dndToggle
        Layout.fillWidth: true
        iconName: Services.NotificationService.dnd ? "bedtime" : "notifications"
        label: Services.I18nService.getTranslation("panel.dnd", "No molestar")
        stateText: Services.NotificationService.dnd ? Services.I18nService.getTranslation("panel.dnd_on", "Activado") : Services.I18nService.getTranslation("panel.dnd_off", "Desactivado")
        active: Services.NotificationService.dnd
        keyboardMode: host.keyboardMode
        onToggled: Services.NotificationService.toggleDnd()
        KeyNavigation.left: cafeToggle
        Keys.onPressed: host.keyboardMode = true
        Keys.onUpPressed: btToggle.forceActiveFocus()
        Keys.onDownPressed: gameToggleItem.forceActiveFocus()
        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(dndToggle);
        }
        onMouseUsed: host.keyboardMode = false
    }
    ControlToggle {
        id: nightToggle
        Layout.fillWidth: true
        iconName: Services.Hyprsunset.nightLightActive ? "bedtime" : "bedtime"
        label: Services.I18nService.getTranslation("panel.night_light", "Luz nocturna")
        stateText: Services.Hyprsunset.nightLightActive ? Services.I18nService.getTranslation("panel.on", "Activado") : Services.I18nService.getTranslation("panel.off", "Desactivado")
        active: Services.Hyprsunset.nightLightActive
        keyboardMode: host.keyboardMode
        onToggled: Services.Hyprsunset.toggleNightLight()
        KeyNavigation.right: gameToggleItem
        Keys.onPressed: host.keyboardMode = true
        Keys.onUpPressed: cafeToggle.forceActiveFocus()
        Keys.onDownPressed: host.focusTab(host.currentTab)
        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(nightToggle);
        }
        onMouseUsed: host.keyboardMode = false
    }
    ControlToggle {
        id: gameToggleItem
        Layout.fillWidth: true
        iconName: "gamepad"
        label: Services.I18nService.getTranslation("panel.game_mode", "Modo de Juego")
        stateText: Services.GameMode.enabled ? Services.I18nService.getTranslation("panel.on", "Activado") : Services.I18nService.getTranslation("panel.off", "Desactivado")
        active: Services.GameMode.enabled
        keyboardMode: host.keyboardMode
        onToggled: Services.GameMode.toggle()
        KeyNavigation.left: nightToggle
        Keys.onPressed: host.keyboardMode = true
        Keys.onUpPressed: dndToggle.forceActiveFocus()
        Keys.onDownPressed: host.focusTab(host.currentTab)
        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(gameToggleItem);
        }
        onMouseUsed: host.keyboardMode = false
    }
}
