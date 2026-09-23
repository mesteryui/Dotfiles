// --- BluetoothPopupContent: dispositivos emparejados con batería ---
pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Modules
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// El panel dimensiona por contenido; solo la sección de búsqueda
// (que crece al escanear) lleva scroll propio con altura tope.
Item {
    id: root

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    // La API expone 0..1; si algún backend diese 0..100, no se rompe.
    function batteryPct(device) {
        if (device?.batteryAvailable === false)
            return -1;
        const v = device?.battery ?? -1;
        if (v < 0)
            return -1;
        return Math.round(v > 1 ? v : v * 100);
    }

    function deviceName(device) {
        return device?.deviceName || device?.name || device?.address || "?";
    }

    function deviceConnected(device) {
        return (device?.state ?? -1) === BluetoothDeviceState.Connected;
    }

    // list<BluetoothDevice> llega como array-like: copia manual.
    // Emparejados, con el conectado primero.
    function pairedDevices() {
        const all = Services.BluetoothService.devices;
        const head = [];
        const tail = [];
        for (let i = 0; i < (all?.length ?? 0); i++) {
            if (!all[i]?.paired)
                continue;
            if (root.deviceConnected(all[i]))
                head.push(all[i]);
            else
                tail.push(all[i]);
        }
        return head.concat(tail);
    }

    // Visibles no emparejados (tras Buscar).
    function unpairedDevices() {
        const all = Services.BluetoothService.devices;
        const out = [];
        for (let i = 0; i < (all?.length ?? 0); i++)
            if (!all[i]?.paired)
                out.push(all[i]);
        return out;
    }

    Timer {
        id: scanTimer

        interval: 15000
        repeat: false
        onTriggered: {
            if (Services.BluetoothService.currentAdapter)
                Services.BluetoothService.currentAdapter.discovering = false;
        }
    }

    implicitWidth: 300
    implicitHeight: mainColumn.implicitHeight

    ColumnLayout {
        id: mainColumn

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: root.tr("panel.bluetooth", "Bluetooth")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.md3.on_surface
            }

            StyledText {
                visible: !Services.BluetoothService.available
                text: root.tr("panel.off", "Desactivado")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.md3.on_surface_variant
            }
        }

        ControlToggle {
            Layout.fillWidth: true
            visible: Services.BluetoothService.available
            label: root.tr("panel.bluetooth", "Bluetooth")
            stateText: Services.BluetoothService.enabled ? root.tr("panel.on", "Activado") : root.tr("panel.off", "Desactivado")
            iconName: Services.BluetoothService.enabled ? "bluetooth" : "bluetooth_disabled"
            active: Services.BluetoothService.enabled
            onToggled: {
                if (Services.BluetoothService.currentAdapter)
                    Services.BluetoothService.currentAdapter.enabled = !Services.BluetoothService.currentAdapter.enabled;
            }
        }

        Repeater {
            model: root.pairedDevices()

            delegate: Rectangle {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: 52
                radius: 14
                color: mouse.containsMouse ? Appearance.md3.secondary_container : Appearance.md3.surface_container_low

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    MaterialIcon {
                        icon: Icons.getBluetoothDeviceMaterialSymbol(modelData?.icon ?? "")
                        size: 20
                        color: root.deviceConnected(modelData) ? Appearance.md3.primary : Appearance.md3.on_surface_variant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.deviceName(modelData)
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: (root.deviceConnected(modelData) ? root.tr("panel.connected", "Conectado") : root.tr("panel.disconnected", "Desconectado")) + (root.batteryPct(modelData) >= 0 ? " · " + root.batteryPct(modelData) + "%" : "")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.md3.on_surface_variant
                            elide: Text.ElideRight
                        }
                    }

                    M3ProgressBar {
                        Layout.preferredWidth: 48
                        visible: root.batteryPct(modelData) >= 0
                        value: root.batteryPct(modelData) / 100
                        implicitHeight: 5
                    }

                    ButtonIcon {
                        iconName: "delete"
                        iconSize: 18
                        onClicked: modelData.forget()
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.deviceConnected(modelData))
                            modelData.disconnect();
                        else
                            modelData.connect();
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            visible: Services.BluetoothService.available && root.pairedDevices().length === 0 && root.unpairedDevices().length === 0
            text: root.tr("panel.bluetooth_empty", "Sin dispositivos emparejados")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.md3.on_surface_variant
            wrapMode: Text.WordWrap
        }

        AnimatedTextButton {
            Layout.alignment: Qt.AlignHCenter
            visible: Services.BluetoothService.available && Services.BluetoothService.enabled
            text: (Services.BluetoothService.currentAdapter?.discovering ?? false) ? root.tr("panel.bluetooth_scanning", "Buscando…") : root.tr("panel.bluetooth_scan", "Buscar")
            onClicked: {
                const adapter = Services.BluetoothService.currentAdapter;
                if (!adapter)
                    return;
                adapter.discovering = !adapter.discovering;
                if (adapter.discovering)
                    scanTimer.restart();
                else
                    scanTimer.stop();
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.unpairedDevices().length > 0
            text: root.tr("panel.bluetooth_available", "Disponibles")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.md3.on_surface
        }

        // Resultados de búsqueda con scroll propio: es lo único que
        // puede crecer sin control y salirse de la pantalla.
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(unpairedColumn.implicitHeight, 220)
            visible: root.unpairedDevices().length > 0
            contentWidth: width
            contentHeight: unpairedColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar {}

            ColumnLayout {
                id: unpairedColumn

                width: parent.width
                spacing: 6

                Repeater {
                    model: root.unpairedDevices()

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 14
                        color: Appearance.md3.surface_container_low

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialIcon {
                                icon: Icons.getBluetoothDeviceMaterialSymbol(modelData?.icon ?? "")
                                size: 20
                                color: Appearance.md3.on_surface_variant
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.deviceName(modelData)
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.md3.on_surface
                                elide: Text.ElideRight
                            }

                            AnimatedTextButton {
                                text: root.tr("panel.bluetooth_pair", "Emparejar")
                                fontSize: 12
                                paddingHorizontal: 12
                                onClicked: modelData.pair()
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: root.unpairedDevices().length > 0
            text: root.tr("panel.bluetooth_pin_hint", "Con PIN usa el gestor")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.md3.on_surface_variant
        }

        AnimatedTextButton {
            Layout.alignment: Qt.AlignHCenter
            text: root.tr("panel.bluetooth_manager", "Abrir gestor")
            onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "bluetui"])
        }
    }
}
