pragma ComponentBehavior: Bound

import qs.Bar.Items
import qs.Core
import QtQuick
import QtQuick.Layouts

// Orden desde ConfigService.configs.bar.{left,center,right} vía BarRegistry.
// BarRegistry vive en el mismo módulo (Bar/), no necesita import.
//
// NOTA: los items se declaran como Components estáticos y el Loader usa
// sourceComponent. Un Loader con `source: <url fichero>` NO resuelve los
// módulos qs.* de este proyecto (qs.Bar.Content, qs.Panels.*, ni los tipos
// del mismo directorio como BarItem/WorkspaceButton). El orden sigue siendo
// dinámico (Repeater sobre sectionModules()), solo la creación es estática.
Item {
    id: bar

    // Id (ya normalizable por BarRegistry) -> Component estático.
    // sectionModules() ya filtra desconocidos; esto es defensa en profundidad.
    function componentFor(moduleId) {
        switch (BarRegistry.normalizeId(moduleId)) {
        case "launcher":
            return launcherComp;
        case "workspaces":
            return workspacesComp;
        case "submap":
            return submapComp;
        case "weather":
            return weatherComp;
        case "mpris":
            return mprisComp;
        case "updates":
            return updatesComp;
        case "clock":
            return clockComp;
        case "tray":
            return trayComp;
        case "network":
            return networkComp;
        case "bluetooth":
            return bluetoothComp;
        case "battery":
            return batteryComp;
        case "volume":
            return volumeComp;
        case "caffeine":
            return caffeineComp;
        case "notifications":
            return notificationsComp;
        default:
            console.warn("MainBar: módulo desconocido '" + moduleId + "', se omite");
            return null;
        }
    }

    Component {
        id: launcherComp

        Launcher {}
    }
    Component {
        id: workspacesComp

        Workspaces {}
    }
    Component {
        id: submapComp

        HyprlandSubmap {}
    }
    Component {
        id: weatherComp

        Weather {}
    }
    Component {
        id: mprisComp

        MprisPlayer {}
    }
    Component {
        id: updatesComp

        UpdateCounter {}
    }
    Component {
        id: clockComp

        Clock {}
    }
    Component {
        id: trayComp

        SysTray {}
    }
    Component {
        id: networkComp

        Network {}
    }
    Component {
        id: bluetoothComp

        Bluetooth {}
    }
    Component {
        id: batteryComp

        Battery {}
    }
    Component {
        id: volumeComp

        Volume {}
    }
    Component {
        id: caffeineComp

        Caffeine {}
    }
    Component {
        id: notificationsComp

        Notifications {}
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: Appearance.spacing.s

            Repeater {
                model: BarRegistry.sectionModules("left")
                delegate: Loader {
                    required property string modelData

                    Layout.alignment: Qt.AlignVCenter
                    // NOTA: no atar `visible` a `item.visible` (verificado en
                    // test: el item nace invisible y la barra queda vacía).
                    // Los módulos que se ocultan solos (submap, updates) ya
                    // vienen filtrados del modelo en sectionModules().
                    Layout.preferredWidth: item ? item.implicitWidth : 0
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    visible: item !== null
                    sourceComponent: bar.componentFor(modelData)
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
            spacing: Appearance.spacing.s

            Repeater {
                model: BarRegistry.sectionModules("center")
                delegate: Loader {
                    required property string modelData

                    Layout.alignment: Qt.AlignVCenter
                    // NOTA: no atar `visible` a `item.visible` (verificado en
                    // test: el item nace invisible y la barra queda vacía).
                    // Los módulos que se ocultan solos (submap, updates) ya
                    // vienen filtrados del modelo en sectionModules().
                    Layout.preferredWidth: item ? item.implicitWidth : 0
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    visible: item !== null
                    sourceComponent: bar.componentFor(modelData)
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: Appearance.spacing.s

            Repeater {
                model: BarRegistry.sectionModules("right")
                delegate: Loader {
                    required property string modelData

                    Layout.alignment: Qt.AlignVCenter
                    // NOTA: no atar `visible` a `item.visible` (verificado en
                    // test: el item nace invisible y la barra queda vacía).
                    // Los módulos que se ocultan solos (submap, updates) ya
                    // vienen filtrados del modelo en sectionModules().
                    Layout.preferredWidth: item ? item.implicitWidth : 0
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    visible: item !== null
                    sourceComponent: bar.componentFor(modelData)
                }
            }
        }
    }
}
