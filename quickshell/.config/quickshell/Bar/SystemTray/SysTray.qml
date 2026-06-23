import QtQuick
import Quickshell.Services.SystemTray
import QtQuick.Layouts
Row {
    id: root
    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: SysTrayItem {
            Layout.alignment: Qt.AlignCenter
        }
    }
}
