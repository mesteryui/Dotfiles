// ControlSlider — Material 3 Expressive Slider primitive.
import QtQuick
import QtQuick.Layouts
import qs.Core

RowLayout {
    id: root

    property string label: ""
    property string iconName: ""
    property real value: 0.0          // 0.0 – 1.0
    property color accentColor: Appearance.md3.primary
    property bool showValue: true
    property string valueText: Math.round(root.value * 100) + "%"

    signal moved(real val)
    signal iconClicked

    spacing: 12

    // Icono Material con feedback interactivo opcional
    MaterialIcon {
        id: iconItem
        visible: root.iconName !== ""
        icon: root.iconName
        size: Appearance.font.pixelSize.large
        color: iconArea.containsMouse ? Appearance.md3.primary : Appearance.md3.on_surface_variant
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    // Pista y Control del Slider estilo M3 Expressive
    Item {
        id: sliderTrackContainer
        Layout.fillWidth: true
        Layout.preferredHeight: 24

        // Pista base (Capsule track)
        Rectangle {
            id: trackBg
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: trackArea.pressed ? 14 : 12
            radius: height / 2
            color: Appearance.md3.surface_container_highest
            Behavior on height {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            // Pista activa (Fill)
            Rectangle {
                width: Math.max(height, trackBg.width * Math.max(0, Math.min(1, root.value)))
                height: parent.height
                radius: parent.radius
                color: root.accentColor
                Behavior on width {
                    NumberAnimation {
                        duration: 80
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }

        // Thumb / Manejador M3 Expressive
        Rectangle {
            id: thumb
            x: Math.max(0, Math.min(sliderTrackContainer.width - width, sliderTrackContainer.width * Math.max(0, Math.min(1, root.value)) - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: trackArea.pressed ? 20 : (trackArea.containsMouse ? 18 : 14)
            height: trackArea.pressed ? 22 : (trackArea.containsMouse ? 20 : 18)
            radius: width / 2
            color: root.accentColor
            border.color: Appearance.md3.surface_container_low
            border.width: 2

            Behavior on x {
                NumberAnimation {
                    duration: 80
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        MouseArea {
            id: trackArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function updateValue(mouseX) {
                const newVal = Math.max(0.0, Math.min(1.0, mouseX / width));
                root.moved(newVal);
            }

            onPositionChanged: mouse => {
                if (pressed)
                    updateValue(mouse.x);
            }
            onClicked: mouse => updateValue(mouse.x)
        }
    }

    // Texto de porcentaje / valor
    StyledText {
        visible: root.showValue
        text: root.valueText
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.family: Appearance.font.sans
        color: Appearance.md3.on_surface_variant
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 36
    }
}
