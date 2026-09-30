import qs.Core
import qs.Shared.Background
import qs.Bar.Content
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var modelData
    required property bool isActive

    visible: modelData.id > 0
    width: isActive ? 40 : 30   // se expande al activarse
    height: 27
    Layout.preferredWidth: width
    Layout.preferredHeight: height

    Behavior on width {
        NumberAnimation {
            duration: Appearance.motion.short4
            easing.type: Easing.OutCubic
        }
    }

    scale: mouseArea.pressed ? 0.85 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: Appearance.motion.short2
            easing.type: Easing.OutQuad
        }
    }
    SurfaceBackground {
        id: background

        anchors.fill: parent
        color: root.isActive ? Appearance.md3.primary : Appearance.md3.secondary_container
        radius: Appearance.shape.verylarge

        Behavior on color {
            ColorAnimation {
                duration: Appearance.motion.short4
            }
        }
    }

    WorkspaceButtonContent {
        anchors.centerIn: parent
        workspaceButton: root.modelData.id
        color: root.isActive ? Appearance.md3.on_primary : Appearance.md3.on_surface
        isFocused: root.isActive
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.modelData.activate()
    }
}
