import qs.Core
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

Row {
    id: root

    spacing: Appearance.spacing.xs

    property alias items: rep.model

    Repeater {
        id: rep

        model: SystemTray.items

        delegate: SysTrayItem {
            Layout.alignment: Qt.AlignCenter
        }
    }
}
