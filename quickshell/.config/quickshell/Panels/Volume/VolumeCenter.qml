import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.Core.Services
import Quickshell.Wayland
import qs.Shared.Background
import qs.Core
import QtQuick.Effects

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

            color: "transparent"
            visible: scope.shown

            implicitWidth: (contentLoader.item ? contentLoader.item.implicitWidth : 300) + 24
            implicitHeight: (contentLoader.item ? contentLoader.item.implicitHeight : 200) + 24

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
            }

            // Sombra: source se asigna en onCompleted para evitar warning
            // "ShaderEffect: 'source' does not have a matching property" del primer frame.
            MultiEffect {
                id: panelShadow
                anchors.fill: bg
                shadowEnabled: true
                shadowColor: Appearance.md3.shadow
                shadowBlur: 0.85
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
                blurMax: 32
                shadowOpacity: Appearance.elevation2.opacity
                z: -1
                Component.onCompleted: panelShadow.source = bg
            }

            // Síncrono a propósito: el contenido mide según datos vivos (número
            // de dispositivos, volúmenes) y en async la ventana abría en tamaño
            // de fallback y saltaba al real, desplazando los sliders a la vista.
            // Es un popup pequeño: instanciar en el mismo frame no se nota y al
            // cerrar se sigue destruyendo (ahorro intacto).
            Loader {
                id: contentLoader

                anchors {
                    fill: parent
                    margins: Appearance.spacing.m
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
