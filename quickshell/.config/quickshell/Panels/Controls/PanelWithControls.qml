// ControlPanel — Wrapper Material 3 Expressive
// Gestiona estado, ciclo de vida y ensambla Background + Content.
// Scope ligero: el IPC vive aquí para responder antes de cargar.
// La PanelWindow solo se instancia al abrir (ahorro en arranque).

pragma ComponentBehavior: Bound

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

    // Métricas al vivo solo mientras el panel está abierto (ver
    // SystemInfoService.setLive): en reposo el backend no calcula CPU/RAM.
    onShownChanged: SystemInfoService.setLive(scope.shown)

    IpcHandler {
        target: "dashboard"

        function toggle() {
            scope.shown = !scope.shown;
        }
    }

    LazyLoader {
        id: controlsLoader

        loading: scope.shown

        component: PanelWindow {
            id: root

            // Color sólido del wrapper: se ve alrededor del fondo redondeado
            // (perímetro exterior de las esquinas del rectángulo con radius).
            // El wrapper no es transparente.
            color: "transparent"
            implicitWidth: 410

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:dashboard"
            exclusiveZone: 0
            visible: scope.shown

            // Altura completa: la ventana se estira de arriba a abajo.
            // Modelo de huecos: cada lado ya viene recortado por su
            // exclusive zone (barra: su alto en Bar.qml; marco hug de
            // Appearance.shape.screenBorder en full_hug) y aquí solo se suma
            // el respiro.
            // Medido: sin esto el panel quedaba un hueco de más a izquierda y
            // abajo en full_hug (el marco también reserva zona).
            readonly property bool barAtBottom: ConfigService.configs.bar.position === "bottom"

            readonly property string barType: GameMode.enabled ? "no_floating" :
                                                                 ConfigService.configs.bar.barType
            // Separación mínima (6px) en todos los límites, haya o no
            // elementos: la barra flotante suma sus 3px de margen exterior.

            readonly property int edgeGap: 6

            readonly property int barClear: (barType === "floating" ? 3 : 0) + edgeGap

            anchors {
                left: true
                top: true
                bottom: true
            }

            margins {
                left: visible ? edgeGap : -implicitWidth - 40
                top: !barAtBottom ? barClear : edgeGap
                bottom: barAtBottom ? barClear : edgeGap
            }

            // Sin animación de slide aquí: el compositor ya anima la capa
            // con `slide left` (layerrules.lua → dashboard). Animar también
            // margins.left duplicaba el movimiento. El salto es instantáneo
            // y Hyprland pone el deslizamiento al mapear/desmapear.

            // ── Datos ─────────────────────────────────────────────────────
            property string username: Quickshell.env("USER")

            // Hostname y recursos del sistema vienen del socket de shinro
            // a través de SystemInfoService (medio primario, siempre conectado).
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

            PopupBackground {
                id: bg

                // Accessible en el contenido (Item), no en la PanelWindow.
                Accessible.role: Accessible.Dialog
                Accessible.name: I18nService.getTranslation("panel.controls", "Centro de control")
                anchors.fill: parent
                surfaceRadius: Appearance.shape.huge
                baseColor: Appearance.md3.surface
                // Sin borde interno: el borde visual lo da el radio del fondo
                // contra el wrapper de color sólido. Un borde como hijo interno
                // de PopupBackground queda tapado por el Content, así que no tiene sentido.
                showBorder: true
            }

            // ── Content (lazy) ────────────────────────────────────────
            // Incluye SysInfoTab (gráficos) + bluetooth/audio: se crea solo al abrir.
            Loader {
                id: contentLoader

                anchors.fill: bg
                active: root.visible
                // Async para no congelar el hilo QML al abrir (el contenido
                // trae SysInfoTab + bluetooth/audio; en sync el slide se
                // atrancaba un frame).
                asynchronous: true
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
