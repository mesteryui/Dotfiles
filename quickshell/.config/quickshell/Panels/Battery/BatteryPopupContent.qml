pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.Core
import qs.Core.Services as Services
import qs.Primitives

Item {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

    readonly property var profiles: [
        PowerProfile.PowerSaver,
        PowerProfile.Balanced,
        PowerProfile.Performance
    ]

    function profileIcon(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver: return "battery_saver"
        case PowerProfile.Performance: return "bolt"
        default: return "balance"
        }
    }

    function profileLabel(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver: return Services.I18nService.getTranslation("battery.powersave")
        case PowerProfile.Performance: return Services.I18nService.getTranslation("battery.performance")
        default: return Services.I18nService.getTranslation("battery.balanced")
        }
    }

    function batteryIcon() {
        if (!hasBattery) return "battery_unknown"
        if (charging) return "battery_charging_full"
        const p = battery ? battery.percentage * 100 : 0
        if (p >= 95) return "battery_full"
        if (p >= 80) return "battery_6_bar"
        if (p >= 60) return "battery_5_bar"
        if (p >= 45) return "battery_4_bar"
        if (p >= 30) return "battery_3_bar"
        if (p >= 15) return "battery_2_bar"
        if (p >= 5)  return "battery_1_bar"
        return "battery_alert"
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0 || isNaN(seconds)) return ""
        const totalMinutes = Math.floor(seconds / 60)
        const hours = Math.floor(totalMinutes / 60)
        const minutes = totalMinutes % 60
        if (hours > 0) {
            return hours + " h " + minutes + " min"
        }
        return minutes + " min"
    }

    function batteryStatusText() {
        if (!hasBattery) return "Batería no detectada"
        if (!battery) return "Estado desconocido"

        switch (battery.state) {
        case UPowerDeviceState.Charging:
            const tFull = formatTime(battery.timeToFull)
            return tFull !== "" ? "Cargando (" + tFull + " para completar)" : "Cargando..."
        case UPowerDeviceState.Discharging:
            const tEmpty = formatTime(battery.timeToEmpty)
            return tEmpty !== "" ? "Restante: " + tEmpty : "En uso de batería"
        case UPowerDeviceState.FullyCharged:
            return "Carga completa"
        case UPowerDeviceState.PendingCharge:
            return "Pendiente de carga"
        case UPowerDeviceState.PendingDischarge:
            return "Pendiente de descarga"
        default:
            return "Desconectado"
        }
    }

    // Ancho sugerido para evitar que los botones queden apretados
    implicitWidth: 340
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 14

        // --- Tarjeta de Estado e Información de Batería ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: batteryCardContent.implicitHeight + 20
            radius: Appearance.shape.normal
            color: Appearance.md3.surface_container_low
            border.color: Appearance.md3.outline_variant
            border.width: 1

            RowLayout {
                id: batteryCardContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Contenedor del Ícono
                Rectangle {
                    implicitWidth: 46
                    implicitHeight: 46
                    radius: Appearance.shape.small
                    color: root.charging
                        ? Appearance.md3.primary_container
                        : Appearance.md3.surface_container_highest

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: root.batteryIcon()
                        size: 26
                        color: root.charging
                            ? Appearance.md3.on_primary_container
                            : Appearance.md3.on_surface
                    }
                }

                // Datos: Porcentaje, Consumo y Tiempo restante
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        spacing: 8
                        StyledText {
                            text: root.hasBattery ? Math.round(root.battery.percentage * 100) + "%" : "N/A"
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.bold: true
                            font.features: ({ "tnum": 1, "lnum": 1 })
                            color: Appearance.md3.on_surface
                        }

                        StyledText {
                            visible: root.hasBattery && root.battery.energyRate > 0
                            text: (Math.round(root.battery.energyRate * 10) / 10) + " W"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.md3.on_surface_variant
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 3
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.batteryStatusText()
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // --- Título para Perfiles ---
        StyledText {
            text: "Perfil de energía"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.bold: true
            color: Appearance.md3.on_surface_variant
            Layout.leftMargin: 4
        }

        // --- Botones de Perfiles de Energía ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.profiles

                delegate: Rectangle {
                    id: profileButton
                    required property var modelData

                    readonly property bool selected: PowerProfiles.profile === modelData
                    readonly property bool profileDisabled:
                        modelData === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 64
                    radius: Appearance.shape.small
                    color: selected ? Appearance.md3.primary_container : Appearance.md3.surface_container_high
                    opacity: profileDisabled ? 0.38 : 1.0

                    Rectangle {
                        id: stateLayer
                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.md3.on_surface
                        opacity: 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4
                        Layout.alignment: Qt.AlignCenter

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: root.profileIcon(profileButton.modelData)
                            size: 22
                            color: profileButton.selected
                                ? Appearance.md3.on_primary_container
                                : Appearance.md3.on_surface_variant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            text: root.profileLabel(profileButton.modelData)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: profileButton.selected
                                ? Appearance.md3.on_primary_container
                                : Appearance.md3.on_surface_variant
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !profileButton.profileDisabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: stateLayer.opacity = 0.08
                        onExited: stateLayer.opacity = 0
                        onPressed: stateLayer.opacity = 0.12
                        onReleased: stateLayer.opacity = containsMouse ? 0.08 : 0
                        onClicked: PowerProfiles.profile = profileButton.modelData
                    }
                }
            }
        }
    }
}