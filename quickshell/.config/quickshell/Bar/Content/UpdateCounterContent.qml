import qs.Core
import qs.Core.Services as Services
import QtQuick
import qs.Primitives

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
            icon: root.service.updating ? "downloading" :
            root.service.checking ? "sync" :
            root.service.failed ? "warning" :
            "system_update_alt"

            color: root.service.failed ? Colors.md3.error :
            root.service.updating ? Colors.md3.primary :
            Colors.md3.on_surface

            // Rotación animada mientras sincroniza
            RotationAnimation on rotation {
            running: root.service.checking || root.service.updating
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite

            onRunningChanged: {
                if (!running)
                {
                    icon.rotation = 0
                }
            }

        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.service.checking && !root.service.updating
        text: root.service.updateCount
        color: root.service.failed ? Colors.md3.error : Colors.md3.on_surface
        font.pixelSize: 16
        font.family: Services.ConfigService.configs.appearence.fontSans
    }
}
}