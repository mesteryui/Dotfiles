import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.Bar.Items
import qs.Bar.SystemTray

Item {
    id: bar
    RowLayout {
        anchors.fill: parent
        spacing: 0

        Row {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 8
            Launcher {}
            Repeater {
                model: Hyprland.workspaces
                delegate: WorkspaceButton {
                    isActive: Hyprland.focusedWorkspace?.id === modelData.id
                }
            }
            HyprlandSubmap {}
        }

        
        Item { Layout.fillWidth: true }

        
        Row {
            Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
            spacing: 12
            MprisPlayer {}
            UpdateCounter {}
            Clock {}
        }

        Item { Layout.fillWidth: true }

        
        Row {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 8

            SysTray {
                Layout.alignment: Qt.AlignVCenter
            }

            Network {}
            Bluetooth {}
            Battery {}
            Volume {}
        }
    }
}