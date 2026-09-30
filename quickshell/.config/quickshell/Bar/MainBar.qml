import qs.Bar.Items
import qs.Core
import QtQuick
import QtQuick.Layouts

Item {
    id: bar

    RowLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: Appearance.spacing.s

            Launcher {}
            Workspaces {}
            HyprlandSubmap {}
        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
            spacing: Appearance.spacing.s

            Weather {}
            MprisPlayer {}
            UpdateCounter {}
            Clock {}
        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: Appearance.spacing.s

            SysTray {}
            Network {}
            Bluetooth {}
            Battery {}
            Volume {}
        }
    }
}
