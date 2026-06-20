import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.Bar.Items
import qs.Bar.SystemTray
import qs.Core

Rectangle {
        id: bar
        anchors.fill: parent
        color: Colors.md3.surface
        radius: 30
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 0

            // Sección Izquierda: Workspaces
            
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

            // Espaciador flexible para centrar
            Item { Layout.fillWidth: true }

            // Sección Central: Media & Clock
            Row {
                Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
                spacing: 12
                MprisPlayer {}
                UpdateCounter {}
                Clock {}
            }

            // Espaciador flexible
            Item { Layout.fillWidth: true }

            // Sección Derecha: Servicios
            Row {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: 8

                SysTray {
                    Layout.alignment: Qt.AlignVCenter
                    rootWindow: root
                }
                
                Network {}
                Bluetooth {}
                Battery {}
                Volume {}
            }
        }
    }