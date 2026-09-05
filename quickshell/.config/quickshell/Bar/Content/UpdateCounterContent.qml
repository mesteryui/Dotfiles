import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick

Item {
    id: root

    implicitHeight: 30
    implicitWidth: layout.childrenRect.width

    required property var service

    Row {
        id: layout

        spacing: 6

        anchors.centerIn: parent

        MaterialIcon {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            size: 20
            renderType: Text.QtRendering
            icon: root.service.updating ? "downloading" : root.service.checking ? "sync" : root.service.failed ? "warning" : "system_update_alt"

            color: root.service.failed ? Appearance.md3.error : root.service.updating ? Appearance.md3.primary : Appearance.md3.on_surface

            // Rotación animada mientras sincroniza
            RotationAnimation on rotation {
                running: root.service.checking || root.service.updating
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite

                onRunningChanged: {
                    if (!running) {
                        icon.rotation = 0;
                    }
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.service.checking && !root.service.updating
            text: root.service.updateCount
            renderType: Text.QtRendering
            color: root.service.failed ? Appearance.md3.error : Appearance.md3.on_surface
            font.pixelSize: 16
        }
    }
}
