import qs.Bar.Items
import qs.Core
import qs.Core.Services as Services
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
            // Plugins al final de la zona (coexistencia: el core no se toca).
            Repeater {
                model: Services.PluginService.widgetsForZone("left")

                delegate: Loader {
                    required property var modelData

                    sourceComponent: modelData.component
                    width: item ? (item.implicitWidth > 0 ? item.implicitWidth : item.width) : 0
                    height: item ? (item.implicitHeight > 0 ? item.implicitHeight : item.height) : 0
                    onLoaded: Services.PluginService.injectContext(item, modelData.id)
                }
            }
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
            Repeater {
                model: Services.PluginService.widgetsForZone("center")

                delegate: Loader {
                    required property var modelData

                    sourceComponent: modelData.component
                    width: item ? (item.implicitWidth > 0 ? item.implicitWidth : item.width) : 0
                    height: item ? (item.implicitHeight > 0 ? item.implicitHeight : item.height) : 0
                    onLoaded: Services.PluginService.injectContext(item, modelData.id)
                }
            }
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
            Repeater {
                model: Services.PluginService.widgetsForZone("right")

                delegate: Loader {
                    required property var modelData

                    sourceComponent: modelData.component
                    width: item ? (item.implicitWidth > 0 ? item.implicitWidth : item.width) : 0
                    height: item ? (item.implicitHeight > 0 ? item.implicitHeight : item.height) : 0
                    onLoaded: Services.PluginService.injectContext(item, modelData.id)
                }
            }
        }
    }
}
