import qs.Core
import qs.Core.Services as Services
import QtQuick
import qs.Components

Row {
    spacing: 6

    property real contentScale


    required property var service

    MaterialIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        size: 20
        icon: service.updating ? "downloading" :
        service.checking ? "sync" :
        service.failed ? "warning" :
        "system_update_alt"

        color: service.failed ? Colors.md3.error :
        service.updating ? Colors.md3.primary :
        Colors.md3.on_surface

        // Rotación animada mientras sincroniza
        RotationAnimation on rotation {
        running: service.checking || service.updating
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
    visible: !service.checking && !service.updating
    text: service.updateCount
    color: service.failed ? Colors.md3.error : Colors.md3.on_surface
    font.pixelSize: 16
    font.family: Services.ConfigService.getConfig("fontSans", "sans-serif")
}
}