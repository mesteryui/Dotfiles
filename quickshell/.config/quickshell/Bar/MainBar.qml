import QtQuick
import QtQuick.Layouts
import qs.Bar.Items

Item {
    id: bar


    RowLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 8
            
            Launcher {}
            Workspaces {}
            HyprlandSubmap {}
        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
            spacing: 8
            
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
            spacing: 8
            
            SysTray {}
            Network {}
            Bluetooth {}
            Battery {}
            Volume {}
        }
    }
}
