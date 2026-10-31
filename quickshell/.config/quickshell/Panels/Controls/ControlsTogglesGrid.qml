// ControlsTogglesGrid — quick settings (WiFi, BT, cafeína, DND, noche, juego).
// Extraído de PanelWithControlsContent.qml. `host` es la raíz del contenido.
pragma ComponentBehavior: Bound

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
    rowSpacing: Appearance.spacing.small
    columnSpacing: Appearance.spacing.small
    uniformCellWidths: true

    // Estado real de luz nocturna al abrir: la conexión al daemon es lazy
    // (no existe hasta el primer uso), así que se establece y sincroniza
    // aquí. El toggle vive en este mismo panel: para cuando el usuario lo
    // mire, el estado ya convergió.
    Component.onCompleted: {
        Services.Hyprsunset.ensureConnected();
        Services.Hyprsunset.syncState();
    }

    // WiFi
    ControlToggle {
        id: wifiToggleItem
        Layout.fillWidth: true

        icon: root.host.wifiEnabled ? "wifi" : "wifi_off"
        label: Services.I18nService.getTranslation("panel.wifi", "WiFi")
        stateText: root.host.wifiEnabled ? Services.I18nService.getTranslation("panel.connected",
                                                                               "Conectado") :
                                           Services.I18nService.getTranslation("panel.disconnected",
                                                                               "Desconectado")
        active: root.host.wifiEnabled
        enable: Networking.wifiHardwareEnabled
        keyboardMode: root.host.keyboardMode
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        KeyNavigation.right: btToggle
        Keys.onPressed: root.host.keyboardMode = true
        Keys.onUpPressed: root.host.focusAboveToggles()
        Keys.onDownPressed: cafeToggle.forceActiveFocus()
        onActiveFocusChanged: {
            if (activeFocus)
                root.host.ensureVisible(wifiToggleItem);
        }
        onMouseUsed: root.host.keyboardMode = false
    }

    // Bluetooth
    ControlToggle {
        id: btToggle
        Layout.fillWidth: true

        icon: root.host.btEnabled ? "bluetooth" : "bluetooth_disabled"
        label: Services.I18nService.getTranslation("panel.bluetooth", "Bluetooth")
        stateText: !root.host.btEnabled ? Services.I18nService.getTranslation("panel.off", "Desactivado") : (
                                              Services.BluetoothService.connectedBatteryPct >= 0
                                              ? Services.I18nService.getTranslation("panel.on", "Activado")
                                                + " · " + Services.BluetoothService.connectedBatteryPct + "%" :
                                                Services.I18nService.getTranslation("panel.on", "Activado"))
        active: root.host.btEnabled
        enable: root.host.btAdapter !== null
        keyboardMode: root.host.keyboardMode
        onToggled: {
            if (root.host.btAdapter)
                root.host.btAdapter.enabled = !root.host.btAdapter.enabled;
        }
        KeyNavigation.left: wifiToggleItem
        Keys.onPressed: root.host.keyboardMode = true
        Keys.onUpPressed: root.host.focusAboveToggles()
        Keys.onDownPressed: dndToggle.forceActiveFocus()
        onActiveFocusChanged: {
            if (activeFocus)
                root.host.ensureVisible(btToggle);
        }
        onMouseUsed: root.host.keyboardMode = false
    }

    // Cafeína
    ControlToggle {
        id: cafeToggle
        Layout.fillWidth: true

        icon: "local_cafe"
        label: Services.I18nService.getTranslation("panel.caffeine", "Cafeína")
        stateText: Services.IdleInhibitedService.inhibited ? Services.I18nService.getTranslation(
                                                                 "panel.caffeine_on", "Activada") :
                                                             Services.I18nService.getTranslation(
                                                                 "panel.caffeine_off", "Desactivada")
        active: Services.IdleInhibitedService.inhibited
        keyboardMode: root.host.keyboardMode
        onToggled: Services.IdleInhibitedService.toggle()
        KeyNavigation.right: dndToggle
        Keys.onPressed: root.host.keyboardMode = true
        Keys.onUpPressed: wifiToggleItem.forceActiveFocus()
        Keys.onDownPressed: nightToggle.forceActiveFocus()
        onActiveFocusChanged: {
            if (activeFocus)
                root.host.ensureVisible(cafeToggle);
        }
        onMouseUsed: root.host.keyboardMode = false
    }

    // No Molestar
    ControlToggle {
        id: dndToggle
        Layout.fillWidth: true

        icon: Services.NotificationData.dnd ? "bedtime" : "notifications"
        label: Services.I18nService.getTranslation("panel.dnd", "No molestar")
        stateText: Services.NotificationData.dnd ? Services.I18nService.getTranslation("panel.dnd_on",
                                                                                       "Activado") :
                                                   Services.I18nService.getTranslation("panel.dnd_off",
                                                                                       "Desactivado")
        active: Services.NotificationData.dnd
        keyboardMode: root.host.keyboardMode
        onToggled: Services.NotificationData.toggleDnd()
        KeyNavigation.left: cafeToggle
        Keys.onPressed: root.host.keyboardMode = true
        Keys.onUpPressed: btToggle.forceActiveFocus()
        Keys.onDownPressed: gameToggleItem.forceActiveFocus()
        onActiveFocusChanged: {
            if (activeFocus)
                root.host.ensureVisible(dndToggle);
        }
        onMouseUsed: root.host.keyboardMode = false
    }
    ControlToggle {
        id: nightToggle
        Layout.fillWidth: true

        icon: Services.Hyprsunset.nightLightActive ? "bedtime" : "bedtime"
        label: Services.I18nService.getTranslation("panel.night_light", "Luz nocturna")
        stateText: Services.Hyprsunset.nightLightActive ? Services.I18nService.getTranslation("panel.on",
                                                                                              "Activado") :
                                                          Services.I18nService.getTranslation("panel.off",
                                                                                              "Desactivado")
        active: Services.Hyprsunset.nightLightActive
        keyboardMode: root.host.keyboardMode
        onToggled: Services.Hyprsunset.toggleNightLight()
        KeyNavigation.right: gameToggleItem
        Keys.onPressed: root.host.keyboardMode = true
        Keys.onUpPressed: cafeToggle.forceActiveFocus()
        Keys.onDownPressed: root.host.focusTab(root.host.currentTab)
        onActiveFocusChanged: {
            if (activeFocus)
                root.host.ensureVisible(nightToggle);
        }
        onMouseUsed: root.host.keyboardMode = false
    }
    ControlToggle {
        id: gameToggleItem
        Layout.fillWidth: true

        icon: "gamepad"
        label: Services.I18nService.getTranslation("panel.game_mode", "Modo de Juego")
        stateText: Services.GameMode.enabled ? Services.I18nService.getTranslation("panel.on", "Activado") :
                                               Services.I18nService.getTranslation("panel.off", "Desactivado")
        active: Services.GameMode.enabled
        keyboardMode: root.host.keyboardMode
        onToggled: Services.GameMode.toggle()
        KeyNavigation.left: nightToggle
        Keys.onPressed: root.host.keyboardMode = true
        Keys.onUpPressed: dndToggle.forceActiveFocus()
        Keys.onDownPressed: root.host.focusTab(root.host.currentTab)
        onActiveFocusChanged: {
            if (activeFocus)
                root.host.ensureVisible(gameToggleItem);
        }
        onMouseUsed: root.host.keyboardMode = false
    }
}
