import QtQuick
import qs.Core
import qs.Primitives

Rectangle {
    id: root
    
    property string text: ""
    property bool isFilled: false
    
    property color baseColor: isFilled ? Appearance.md3.primary : "transparent"
    property color textColor: isFilled ? Appearance.md3.on_primary : Appearance.md3.primary
    property color overlayColor: isFilled ? Appearance.md3.on_primary : Appearance.md3.on_surface
    
    // Customization props
    property int buttonHeight: 36
    property int fontSize: 14
    property int fontWeight: Font.Normal
    property int paddingHorizontal: 32

    signal clicked()

    implicitWidth: textLabel.implicitWidth + paddingHorizontal
    implicitHeight: buttonHeight
    radius: 9999 // full shape token
    color: root.baseColor
    opacity: enabled ? 1.0 : 0.5
    
    // Added scaling effect like the MPRIS buttons and Action chips
    scale: mouseArea.pressed ? 0.94 : (mouseArea.containsMouse ? 1.04 : 1.0)
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.overlayColor
        opacity: mouseArea.pressed ? 0.12 : (mouseArea.containsMouse ? 0.08 : 0)
        Behavior on opacity { NumberAnimation { duration: 100 } }
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
