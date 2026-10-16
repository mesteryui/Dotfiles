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
        id: controlsLoader

        loading: scope.shown

        component: PanelWindow {
            id: root

            color: "transparent"

            implicitWidth: 410

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:dashboard"
            exclusiveZone: 0
            visible: scope.shown

            // Altura completa: la ventana se estira de arriba a abajo.
            // Modelo de huecos: cada lado ya viene recortado por su
            // exclusive zone (barra: su alto en Bar.qml; líneas hug de 10px
            // de ScreenRounding en full_hug) y aquí solo se suma el respiro.
            // Medido: sin esto el panel quedaba 10px de más a izquierda y
            // abajo en full_hug (las líneas también reservan zona).
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

            PopupBackground {
                id: bg

                // Accessible en el contenido (Item), no en la PanelWindow.
                Accessible.role: Accessible.Dialog
                Accessible.name: I18nService.getTranslation("panel.controls", "Centro de control")
                anchors.fill: parent

                radius: Appearance.shape.verylarge
                color: Appearance.md3.surface
            }

            // Sombra: source se asigna en onCompleted para evitar warning
            // "ShaderEffect: 'source' does not have a matching property" del primer frame.
            MultiEffect {
                id: panelShadow

                anchors.fill: bg
                shadowEnabled: true
                shadowColor: Appearance.md3.shadow ?? "#000000"
                shadowOpacity: Appearance.elevation4.opacity
                shadowBlur: Appearance.elevation4.blur
                shadowVerticalOffset: Appearance.elevation4.offsetY
                shadowHorizontalOffset: 2
                z: -1
                Component.onCompleted: panelShadow.source = bg
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
