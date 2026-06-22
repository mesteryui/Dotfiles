import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
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
