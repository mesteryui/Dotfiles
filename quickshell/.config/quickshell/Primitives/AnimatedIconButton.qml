import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Effects

Item {
    id: root
    
    property string iconName: ""
    property int iconSize: 24
    property bool isActive: false
    
    property color baseColor: "transparent"
    property color accentColor: Appearance.md3.primary
    
    // Icon colors based on state
    property color iconColor: Appearance.md3.on_surface
    property color activeIconColor: Appearance.md3.on_primary
    property color disabledIconColor: Qt.alpha(Appearance.md3.on_surface, 0.38)
    
    // Customization
    property bool hasShadow: false
    
    signal clicked()

    implicitWidth: 44
    implicitHeight: 44

    scale: mouseArea.pressed ? 0.92 : (mouseArea.containsMouse ? 1.06 : 1.0)

    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    MultiEffect {
        anchors.fill: bgRect
        source: bgRect
        visible: root.hasShadow
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: 0.22
        shadowBlur: 0.5
        shadowVerticalOffset: 3
    }

    Rectangle {
        id: bgRect

        anchors.fill: parent
        radius: width / 2
        color: root.isActive ? root.accentColor : root.baseColor

        Behavior on color { ColorAnimation { duration: 150 } }
        
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.isActive ? Appearance.md3.on_primary : Appearance.md3.on_surface
            opacity: mouseArea.pressed ? 0.12 : (mouseArea.containsMouse ? 0.08 : 0)

            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        icon: root.iconName
        size: root.iconSize
        color: root.enabled ? (root.isActive ? root.activeIconColor : root.iconColor) : root.disabledIconColor

        Behavior on color { ColorAnimation { duration: 150 } }
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
