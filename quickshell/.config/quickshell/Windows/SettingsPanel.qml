import qs.Core
import qs.Core.Services
import qs.Shared.Background
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Scope ligero: el IPC vive aquí para responder antes de cargar.
// La FloatingWindow solo se instancia al abrir (ahorro en arranque).
Scope {
    id: scope

    property bool shown: false

    // ── IPC ─────────────────────────────────────────────────────────
    // qs ipc call ui.settings toggle
    IpcHandler {
        target: "ui.settings"

        function toggle() {
            scope.shown = !scope.shown;
        }

        function open() {
            scope.shown = true;
        }

        function close() {
            scope.shown = false;
        }
    }

    LazyLoader {
        id: settingsLoader
        loading: scope.shown

        component: FloatingWindow {
            id: root

            color: "transparent"

            implicitWidth: 460
            implicitHeight: 720
            title: "ShinroShell Settings"
            visible: scope.shown

            onClosed: scope.shown = false

            // ── Ciclo de vida ──────────────────────────────────────────────
            HyprlandFocusGrab {
                windows: [root]
                active: scope.shown
                onCleared: Qt.callLater(() => scope.shown = false)
            }

            PopupBackground {
                id: bg

                // Accessible en el contenido (Item), no en la FloatingWindow.
                Accessible.role: Accessible.Dialog
                Accessible.name: I18nService.getTranslation("settings.title", "Ajustes")

                anchors.fill: parent
                // Spec M3 basic-dialog: 28dp (verylarge).
                surfaceRadius: Appearance.shape.verylarge
                baseColor: Appearance.md3.surface
                showBorder: false
            }

            // ── Sombra: source se asigna en onCompleted para evitar warning
            // "ShaderEffect: 'source' does not have a matching property" ──
            MultiEffect {
                id: panelShadow
                anchors.fill: bg
                shadowEnabled: true
                shadowColor: Appearance.md3.shadow
                shadowOpacity: Appearance.elevation4.opacity
                shadowBlur: Appearance.elevation4.blur
                shadowVerticalOffset: Appearance.elevation4.offsetY
                shadowHorizontalOffset: 2
                z: -1
                Component.onCompleted: panelShadow.source = bg
            }

            // ── Content (lazy) ────────────────────────────────────────
            // SettingsPanelContent es pesado y el panel pasa el 99% del tiempo
            // oculto: se difiere sin cambiar IPC ni comportamiento.
            Loader {
                id: contentLoader

                anchors.fill: bg
                active: root.visible
                asynchronous: true
                sourceComponent: settingsComp
            }

            Component {
                id: settingsComp

                SettingsPanelContent {
                    anchors.fill: parent
                }
            }
        }
    }
}
