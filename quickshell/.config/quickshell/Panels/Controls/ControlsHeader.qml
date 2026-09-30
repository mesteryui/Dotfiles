// ControlsHeader — avatar, usuario y botón de apagado.
// Extraído de PanelWithControlsContent.qml. `host` es la raíz del
// contenido (misma semántica que el antiguo `root.`); `focusBelow`
// es el primer foco bajo la cabecera (volumeSlider).
import qs.Core
import qs.Core.Modules
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

RowLayout {
    id: root

    property var host
    property Item focusBelow
    property alias powerButton: powerButtonItem

    spacing: Appearance.spacing.m

    // Avatar circular (misma técnica que LockScreenContent):
    // StyledClippingRectangle con radius width/2 recorta
    // la foto a círculo. Sin borde.
    StyledClippingRectangle {
        Layout.preferredWidth: 50
        Layout.preferredHeight: 50
        Layout.alignment: Qt.AlignVCenter
        radius: Appearance.shape.full
        border.width: 2
        border.color: Appearance.md3.primary
        Image {
            id: faceImage

            anchors.fill: parent
            source: Qt.resolvedUrl(Directories.home + "/.face")
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 44
            sourceSize.height: 44
            asynchronous: true
            cache: true
            visible: status === Image.Ready
        }
    }

    // Nombre + Hostname
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        StyledText {
            text: host.username || "usuario"
            color: Appearance.md3.on_surface
            font.pixelSize: Appearance.typeScale.bodyLarge
            font.weight: Font.Medium
            font.family: Appearance.font.sans
        }
        StyledText {
            text: host.hostname || "localhost"
            color: Appearance.md3.on_surface_variant
            font.pixelSize: Appearance.typeScale.labelMedium
            font.family: Appearance.font.sans
        }
    }

    Item {
        Layout.fillWidth: true
    }

    // Botón apagar sesión (Power Button con micro-animación)
    Rectangle {
        id: powerButtonItem

        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: Appearance.shape.full
        color: powerArea.pressed ? host.withAlpha(Appearance.md3.error_container, 0.9) : (powerArea.containsMouse ? host.withAlpha(Appearance.md3.error_container, 0.4) : Appearance.md3.surface_container_high)
        border.width: (activeFocus && host.keyboardMode) ? 2 : 0
        border.color: Appearance.md3.primary
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: "Apagar sesión"

        Keys.onPressed: host.keyboardMode = true
        Keys.onReturnPressed: buttonProc.running = true
        Keys.onEnterPressed: buttonProc.running = true
        Keys.onSpacePressed: buttonProc.running = true
        Keys.onDownPressed: (focusBelow ? focusBelow.forceActiveFocus() : undefined)

        onActiveFocusChanged: {
            if (activeFocus)
                host.ensureVisible(powerButton);
        }

        scale: powerArea.pressed ? 0.92 : (powerArea.containsMouse ? 1.06 : 1.0)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.motion.short3
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            icon: "power_settings_new"
            size: Appearance.font.pixelSize.large
            color: powerArea.containsMouse ? Appearance.md3.error : Appearance.md3.on_surface_variant

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.motion.short3
                }
            }
        }

        MouseArea {
            id: powerArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: host.keyboardMode = false
            onPressed: {
                powerButtonItem.forceActiveFocus();
                host.keyboardMode = false;
            }
            onClicked: buttonProc.running = true

            Process {
                id: buttonProc

                // Sin `bash -c` intermedio: argv directo al mismo
                // endpoint que usa el atajo de hyprland.
                command: ["qs", "ipc", "call", "ui.powermenu", "togglePowerMenu"]
            }
        }
    }
}
