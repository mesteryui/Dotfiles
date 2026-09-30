import qs.Core
import qs.Primitives
import QtQuick

Rectangle {
    id: root

    property string text: ""
    property bool isFilled: false

    property color baseColor: isFilled ? Appearance.md3.primary : "transparent"
    property color textColor: isFilled ? Appearance.md3.on_primary : Appearance.md3.primary
    property color overlayColor: isFilled ? Appearance.md3.on_primary : Appearance.md3.on_surface

    // Customization props (spec M3 buttons: altura 40dp, radio full).
    property int buttonHeight: 40
    property int fontSize: 14
    property int fontWeight: Font.Normal
    property int paddingHorizontal: 24

    signal clicked()

    implicitWidth: textLabel.implicitWidth + paddingHorizontal
    implicitHeight: buttonHeight
    // Spec M3E buttons: la forma morfea al pulsar (full → squircle).
    radius: mouseArea.pressed ? Appearance.shape.small : Appearance.shape.full

    Behavior on radius {
        NumberAnimation {
            duration: Appearance.motion.short3
        }
    }
    color: root.baseColor
    opacity: enabled ? 1.0 : Appearance.state.disabled

    // Added scaling effect like the MPRIS buttons and Action chips
    scale: mouseArea.pressed ? 0.94 : (mouseArea.containsMouse ? 1.04 : 1.0)

    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }
    Behavior on opacity { NumberAnimation { duration: Appearance.motion.short3 } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.overlayColor
        opacity: mouseArea.pressed ? Appearance.state.pressed : (mouseArea.containsMouse ? Appearance.state.hovered : 0)

        Behavior on opacity { NumberAnimation { duration: Appearance.motion.short2 } }
    }

    StyledText {
        id: textLabel

        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
