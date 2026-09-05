pragma ComponentBehavior: Bound

import qs.Primitives
import qs.Shared.Background
import qs.Core
import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
    id: scope

    property bool shown: false

    IpcHandler {
        target: "switcher"

        function toggle() {
            scope.shown = !scope.shown;
        }
    }
    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "windowSwitcher"
        description: "Window switcher Toggle"
        onPressed: {
            scope.shown = !scope.shown;
        }
    }

    Loader {
        active: scope.shown
        sourceComponent: PanelWindow {
            id: root

            implicitWidth: 620
            implicitHeight: 180
            color: "transparent"

            visible: true

            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore

            // Imprescindible en layer-shell: sin esto el teclado no llega nunca a la
            // surface (mismo pitfall que ya nos mordió con el app launcher).
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // windows: a qué ventana se ata el grab. active: cuándo está agarrando
            // input. Estaban mezclados (un array en una propiedad bool), así que el
            // grab nunca se activaba de verdad y el click afuera no hacía nada.
            HyprlandFocusGrab {
                windows: [root]
                active: root.visible
                onCleared: {
                    if (root.visible)
                        root.visible = false;
                }
            }

            // Con OnDemand nadie tiene el foco de teclado hasta que alguien lo pide
            // explícitamente. windowList.focus = true solo lo marca como candidato
            // dentro del focus scope; esto es lo que realmente empuja el foco a la
            // ventana cuando se abre.
            onVisibleChanged: {
                if (root.visible)
                    windowList.forceActiveFocus();
            }

            // Fondo primero: si se declara después del ListView lo tapa por completo.
            PopupBackground {
                anchors.fill: parent
            }

            ListView {
                id: windowList

                anchors.fill: parent
                anchors.margins: 12
                focus: true

                orientation: ListView.Horizontal
                clip: true
                // El spacing global se pone a 0. Lo gestionaremos dentro del delegado
                // para que las "ventanas fantasma" no dejen huecos vacíos.
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds

                model: Hyprland.toplevels

                highlightMoveDuration: 150
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: width
                highlight: Rectangle {
                    radius: 12
                    color: Appearance.md3.primary
                    opacity: 0.15
                }

                WheelHandler {
                    onWheel: event => windowList.contentX -= event.angleDelta.y
                }

                Keys.onLeftPressed: windowList.decrementCurrentIndex()

                Keys.onRightPressed: windowList.incrementCurrentIndex()

                Keys.onTabPressed: currentIndex === model.count - 1 ? currentIndex = 0 : incrementCurrentIndex()

                Keys.onReturnPressed: windowList.activateCurrent()

                Keys.onEnterPressed: windowList.activateCurrent()

                function activateCurrent() {
                    const toplevel = windowList.currentItem?.modelData;
                    if (!toplevel)
                        return;

                    // Validación segura por si wayland es null
                    toplevel.wayland?.activate();

                    root.visible = false;
                }

                // En lugar de un Rectangle directo, usamos un Item contenedor para gestionar la visibilidad y el tamaño
                delegate: Item {
                    id: windowDelegate
                    // Usamos 'var' en lugar del tipo estricto para evitar errores internos de QML si se le pasa null temporalmente

                    required property var modelData
                    required property int index

                    // Lógica para definir qué es una ventana "real"
                    property bool isRealWindow: {
                        if (!modelData)
                            return false;

                        // Extraemos el appId de forma segura. Las ventanas internas o dummy rara vez tienen appId/windowClass
                        const appId = (modelData.wayland ? modelData.wayland.appId : "") || modelData.windowClass || modelData.initialClass;

                        return (appId !== undefined && appId !== "");
                    }

                    // Si es real, ocupa su ancho (140) + el espaciado deseado (8). Si no, ocupa 0.
                    width: isRealWindow ? 140 + 8 : 0
                    height: ListView.view.height
                    visible: isRealWindow
                    clip: true // Impide que se renderice contenido fuera del ancho 0

                    Rectangle {
                        width: 140
                        height: parent.height
                        radius: 12
                        color: "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            width: parent.width - 16

                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitSize: 42
                                source: {
                                    const tl = windowDelegate.modelData;
                                    if (!tl)
                                        return ""; // Protección contra null

                                    const appId = (tl.wayland ? tl.wayland.appId : "") || tl.windowClass || tl.initialClass;
                                    return Icons.getAppIcon(appId, "application-x-executable");
                                }
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                // Protección segura para extraer el título
                                text: windowDelegate.modelData && windowDelegate.modelData.title ? windowDelegate.modelData.title : ""
                                elide: Text.ElideRight
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: windowList.currentIndex = windowDelegate.index
                            onClicked: {
                                windowList.currentIndex = windowDelegate.index;
                                windowList.activateCurrent();
                            }
                        }
                    }
                }
            }
        }
    }
}
