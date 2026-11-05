pragma ComponentBehavior: Bound

import qs.Core.Services
import qs.Shared.Background
import qs.Core
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Scope ligero: el Ipc/GlobalShortcut vive aquí para responder antes de
// cargar. La PanelWindow pesada solo se instancia al abrir (ahorro en arranque).
Scope {
    id: scope

    property bool shown: false

    GlobalShortcut {
        name: "audio_panel"
        description: "Toggle Audio Panel"
        onPressed: scope.shown = !scope.shown
    }

    LazyLoader {
        loading: scope.shown

        component: PanelWindow {
            id: root

            visible: scope.shown

            implicitWidth: (contentLoader.item ? contentLoader.item.implicitWidth : 300) + 24
            implicitHeight: (contentLoader.item ? contentLoader.item.implicitHeight : 200) + 24
            color: "transparent"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            HyprlandFocusGrab {
                windows: [root]
                active: scope.shown
                onCleared: {
                    if (scope.shown)
                        Qt.callLater(() => scope.shown = false);
                }
            }

            // Escape cierra. M/mute se maneja en el foco:
            // bigButton con Enter/Espacio, sliders con M.
            Shortcut {
                sequence: "Escape"
                onActivated: scope.shown = false
            }

            onVisibleChanged: {
                if (visible)
                    Qt.callLater(() => contentLoader.item?.focusDefault?.());
            }

            PopupBackground {
                id: bg

                // Accessible en el contenido (Item), no en la PanelWindow.
                Accessible.role: Accessible.Dialog
                Accessible.name: I18nService.getTranslation("panel.volume", "Volumen")

                anchors.fill: parent
                surfaceRadius: Appearance.shape.card
                baseColor: Appearance.md3.surface
                showBorder: true
            }


            // Síncrono a propósito: el contenido mide según datos vivos (número
            // de dispositivos, volúmenes) y en async la ventana abría en tamaño
            // de fallback y saltaba al real, desplazando los sliders a la vista.
            // Es un popup pequeño: instanciar en el mismo frame no se nota y al
            // cerrar se sigue destruyendo (ahorro intacto).
            // El contenido llena bg (con clip y radius), no el padre
            // directo, y no renderiza bordes propios.
            Loader {
                id: contentLoader

                anchors {
                    fill: bg
                    margins: Appearance.spacing.medium
                }
                active: root.visible
                sourceComponent: volumeComp
                onLoaded: {
                    if (root.visible)
                        Qt.callLater(() => contentLoader.item?.focusDefault?.());
                }
            }

            Component {
                id: volumeComp

                VolumePopupContent {
                    anchors.fill: parent
                }
            }
        }
    }
}
