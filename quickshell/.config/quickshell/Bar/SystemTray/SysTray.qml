import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../../"
import QtQuick.Layouts
Row {
    id: root
    spacing: 6

    required property var rootWindow

    Repeater {
        model: SystemTray.items

        delegate: SysTrayItem {
            Layout.alignment: Qt.AlignCenter
            rootWindow: root.rootWindow
        }
    }
}
