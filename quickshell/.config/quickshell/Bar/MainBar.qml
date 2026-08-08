import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.Bar.Items
import qs.Primitives
import qs.Bar.SystemTray

Item {
    id: bar

    RowLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
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

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
            spacing: 8
            MprisPlayer {}
            UpdateCounter {}
            Weather {}
            Clock {}
        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 8
            MaterialIcon {
                icon: revealer.reveal ? "chevron_forward" : "chevron_backward"
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        revealer.reveal = !revealer.reveal;
                    }
                }
                NumberAnimation {
                    duration: 200
                    easing: Easing.OutQuad
                }
            }
            Revealer {
                id: revealer
                Layout.alignment: Qt.AlignVCenter
                reveal: false
                vertical: false
                SysTray {
                    id: sysTray
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Network {}
            Bluetooth {}
            Battery {}
            Volume {}
        }
    }
}
