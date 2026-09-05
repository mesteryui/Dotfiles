import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

Row {
    id: root

    spacing: 4

    property alias items: rep.model

    Repeater {
        id: rep

        model: SystemTray.items

        delegate: SysTrayItem {
            Layout.alignment: Qt.AlignCenter
        }
    }
}
