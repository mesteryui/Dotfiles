import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Bar.Items
import qs.Primitives
import qs.Bar.SystemTray

Item {
    id: bar
    required property bool isVertical /* pásalo desde Bar.qml como property, ej Services.ConfigService.configs.bar.position en {"left","right"} */

    Loader {
        anchors.fill: parent
        sourceComponent: bar.isVertical ? verticalLayout : horizontalLayout
    }

    Component {
        id: verticalLayout
        ColumnLayout {
            spacing: 0
            ColumnLayout {
                Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
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
                Layout.fillHeight: true
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                spacing: 8
                MprisPlayer {}
                UpdateCounter {}
                Clock {}
            }
            Item {
                Layout.fillHeight: true
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                spacing: 8
                MaterialIcon {
                    icon: revealer.reveal ? "chevron_forward" : "chevron_backward"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: revealer.reveal = !revealer.reveal
                    }
                }
                Revealer {
                    id: revealer
                    Layout.alignment: Qt.AlignHCenter
                    reveal: false
                    vertical: false
                    SysTray {
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
                Network {}
                Bluetooth {}
                Battery {}
                Volume {}
            }
        }
    }

    Component {
        id: horizontalLayout
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
                        duration: 200;
                        easing: Easing.OutQuad
                    }
                }
                Revealer {
                    id: revealer
                    Layout.alignment: Qt.AlignVCenter
                    reveal: false
                    vertical: true
                    SysTray {
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
}
