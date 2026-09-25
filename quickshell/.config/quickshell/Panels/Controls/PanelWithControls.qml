// ControlPanel — Wrapper Material 3 Expressive
// Gestiona estado, ciclo de vida y ensambla Background + Content.
// Scope ligero: el IPC vive aquí para responder antes de cargar.
// La PanelWindow solo se instancia al abrir (ahorro en arranque).

import qs.Core.Services
import qs.Shared.Background
import qs.Core
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: scope

    property bool shown: false

    IpcHandler {
        target: "dashboard"

        function toggle() {
            scope.shown = !scope.shown;
        }
    }

    LazyLoader {
        loading: scope.shown

        component: PanelWindow {
            id: root

            color: "transparent"

            // ── Límites de altura ───────────────────────────────────────────
            // Ajusta barHeight al alto real de tu barra superior (o el gap que
            // quieras respetar si tu barra está en otro borde).

            implicitWidth: 410
            implicitHeight: 800

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:dashboard"
            exclusiveZone: 0
            visible: scope.shown

            anchors {
                left: true
                top: true
            }

            margins {
                left: visible ? 8 : -implicitWidth - 40
                top: 30
            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on margins.left {
                id: slideAnim

                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            // ── Datos ─────────────────────────────────────────────────────
            property string username: Quickshell.env("USER")

            // Sin proceso `hostname` dedicado: viene del bucle de SystemInfoService.
            property string hostname: SystemInfoService.hostname

            readonly property var btAdapter: BluetoothService.currentAdapter

            readonly property var audioSink: AudioService.audio

            // ── Ciclo de vida ────────────────────────────────────────────
            HyprlandFocusGrab {
                windows: [root]
                active: scope.shown
                onCleared: Qt.callLater(() => scope.shown = false)
            }

            Shortcut {
                sequence: "Escape"
                onActivated: scope.shown = false
            }

            // Demanda pareada sobre SystemInfoService: adquirir al abrir y liberar
            // al cerrar (con guardia para no desbalancear el contador si visible
            // cambia dos veces seguidas al mismo valor, y liberación al destruir).
            property bool _sysInfoAcquired: false

            function syncSysInfoDemand() {
                if (scope.shown && !root._sysInfoAcquired) {
                    SystemInfoService.acquire();
                    root._sysInfoAcquired = true;
                } else if (!scope.shown && root._sysInfoAcquired) {
                    SystemInfoService.release();
                    root._sysInfoAcquired = false;
                }
            }

            Component.onDestruction: {
                if (root._sysInfoAcquired)
                    SystemInfoService.release();
            }

            onVisibleChanged: {
                // Foco inicial silencioso: el teclado funciona desde el primer
                // momento pero sin anillo visible hasta que se pulse una tecla.
                // El contenido es lazy: puede no existir aún en la primera apertura
                // (onLoaded del Loader lo enfoca al completarse).
                syncSysInfoDemand();
                if (visible)
                    Qt.callLater(() => contentLoader.item?.focusDefault?.());
            }

            // En la primera apertura el item se crea ya visible: onVisibleChanged
            // no se dispara al crear, así que se adquiere la demanda aquí.
            Component.onCompleted: {
                if (scope.shown)
                    syncSysInfoDemand();
            }

            // ── Background & Sombra Tonal M3 Expressive ───────────────────
            MultiEffect {
                source: bg
                anchors.fill: bg
                shadowEnabled: true
                shadowColor: Appearance.md3.shadow ?? "#000000"
                shadowOpacity: 0.20
                shadowBlur: 0.8
                shadowVerticalOffset: 4
                shadowHorizontalOffset: 2
                z: -1
            }

            PopupBackground {
                id: bg

                // Accessible en el contenido (Item), no en la PanelWindow.
                Accessible.role: Accessible.Dialog
                Accessible.name: I18nService.getTranslation("panel.controls", "Centro de control")
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                implicitHeight: root.implicitHeight
                radius: Appearance.shape.verylarge
                color: Appearance.md3.surface
            }

            // ── Content (lazy) ────────────────────────────────────────
            // Incluye SysInfoTab (gráficos) + bluetooth/audio: se crea solo al abrir.
            Loader {
                id: contentLoader

                anchors {
                    top: bg.top
                    left: bg.left
                    right: bg.right
                    bottom: bg.bottom
                }
                active: root.visible
                asynchronous: false
                sourceComponent: panelComp
                onLoaded: {
                    if (root.visible)
                        Qt.callLater(() => contentLoader.item?.focusDefault?.());
                }
            }

            Component {
                id: panelComp

                PanelWithControlsContent {
                    anchors.fill: parent
                    username: root.username
                    hostname: root.hostname
                    btAdapter: root.btAdapter
                    audioSink: root.audioSink
                }
            }
        }
    }
}
