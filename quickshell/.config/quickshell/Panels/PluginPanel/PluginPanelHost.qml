import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Core.Services
import qs.Shared.Background
import qs.Core

// Host genérico de paneles de plugins (ver PLUGINS.md).
// Un solo PanelWindow que muestra el componente del plugin activo
// (PluginService.activePanelId). Apertura por IPC:
//   qs ipc call plugins open-panel <id>  (cierre: close-panel)
// o desde una entrada ipc del propio menú launcher del plugin.
// Patrón VolumeCenter: Scope ligero + LazyLoader (la ventana pesada
// solo existe abierta) + foco + Escape + click-fuera.
Scope {
    id: scope

    property bool shown: PluginService.activePanelId !== ""

    LazyLoader {
        loading: scope.shown

        component: PanelWindow {
            id: root

            color: "transparent"
            visible: scope.shown

            implicitWidth: (contentLoader.item ? contentLoader.item.implicitWidth : 320) + 24
            implicitHeight: (contentLoader.item ? contentLoader.item.implicitHeight : 200) + 24

            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            HyprlandFocusGrab {
                windows: [root]
                active: scope.shown
                onCleared: {
                    if (scope.shown)
                        Qt.callLater(() => PluginService.closePanel());
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: PluginService.closePanel()
            }

            PopupBackground {
                anchors.fill: parent
            }

            Loader {
                id: contentLoader

                anchors {
                    fill: parent
                    margins: Appearance.spacing.m
                }
                active: root.visible
                sourceComponent: PluginService.panelComponent(PluginService.activePanelId)
                onLoaded: {
                    // Contexto opcional: si la raíz lo declara lo recibe,
                    // si no usa la API singleton directamente.
                    PluginService.injectContext(item, PluginService.activePanelId);
                }
            }
        }
    }
}
