import QtQuick
import Quickshell.Services.SystemTray
import QtQuick.Layouts
Row {
    id: root
    spacing: 6

    property alias items: rep.model

    Repeater {
        id: rep
        model: SystemTray.items

        delegate: SysTrayItem {
            Layout.alignment: Qt.AlignCenter
        }
    }
}
