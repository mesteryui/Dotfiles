pragma ComponentBehavior: Bound

import qs.Core
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool failed: false
    property string errorString: ""

    // Conecta con el global de Quickshell para escuchar las señales de
    // recarga.
    Connections {
        target: Quickshell

        function onReloadCompleted() {
            root.failed = false;
            popupLoader.loading = true;
        }

        function onReloadFailed(error: string) {
            // Cierra cualquier popup existente antes de crear uno nuevo.
            popupLoader.active = false;

            root.failed = true;
            root.errorString = error;
            popupLoader.loading = true;
        }
    }

    // El popup vive en un loader porque casi nunca hace falta.
    LazyLoader {
        id: popupLoader

        PanelWindow {
            id: popup

            exclusiveZone: 0
            anchors.top: true
            margins.top: 0

            implicitWidth: rect.width + shadow.radius * 2
            implicitHeight: rect.height + shadow.radius * 2

            WlrLayershell.namespace: "quickshell:reloadPopup"

            // color blending is a bit odd as detailed in the type reference.
            color: "transparent"

            Rectangle {
                id: rect

                anchors.centerIn: parent
                color: root.failed ? Appearance.md3.error_container : Appearance.md3.tertiary_container

                implicitHeight: layout.implicitHeight + 30
                implicitWidth: layout.implicitWidth + 30
                radius: 12

                // Cubre toda el área del rectángulo y captura los clics,
                // que descartan el popup.
                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    onPressed: popupLoader.active = false

                    // Hace que el ratón siga el hover para poder pausar la
                    // animación de ocultado.
                    hoverEnabled: true
                }

                ColumnLayout {
                    id: layout

                    spacing: 10
                    anchors {
                        top: parent.top
                        topMargin: 10
                        horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.family: "Google Sans Flex"
                        font.pointSize: 14
                        text: root.failed ? "Quickshell: Reload failed" : "Quickshell reloaded"
                        color: root.failed ? Appearance.md3.on_error_container :
                                             Appearance.md3.on_tertiary_container
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.family: "JetBrainsMono Nerd Font"
                        font.pointSize: 11
                        text: root.errorString
                        color: root.failed ? Appearance.md3.on_error_container :
                                             Appearance.md3.on_tertiary_container
                        // Cuando visible es false tampoco ocupa espacio.
                        visible: root.errorString != ""
                    }
                }

                // Barra de progreso en la base: cuánto falta para que el
                // popup desaparezca.
                Rectangle {
                    id: bar

                    z: 2
                    color: root.failed ? Appearance.md3.error : Appearance.md3.tertiary
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 10
                    height: 5
                    radius: 9999

                    PropertyAnimation {
                        id: anim

                        target: bar
                        property: "width"
                        from: rect.width - bar.anchors.margins * 2
                        to: 0
                        duration: root.failed ? 10000 : 1000
                        onFinished: popupLoader.active = false

                        // Pausa la animación con el ratón encima, para que
                        // el popup siga visible mientras se lee. Se
                        // reevalúa solo al entrar/salir del popup.
                        paused: mouseArea.containsMouse
                    }
                }

                // Pista de la barra de progreso.
                Rectangle {
                    id: barBg

                    z: 1
                    color: root.failed ? Qt.alpha(Appearance.md3.error, 0.19) : Qt.alpha(
                                             Appearance.md3.tertiary, 0.25)
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 10
                    height: 5
                    radius: 9999
                    width: rect.width - bar.anchors.margins * 2
                }

                // No se pone `running: true` dentro de la animación: el
                // ancho del rectángulo aún puede no estar calculado por el
                // layout. En Component.onCompleted todos los hijos ya están
                // inicializados.
                Component.onCompleted: anim.start()
            }

            DropShadow {
                id: shadow

                anchors.fill: rect
                horizontalOffset: 0
                verticalOffset: 2
                radius: 6
                samples: radius * 2 + 1 // Idealmente 2 * radius + 1, ver docs de Qt
                color: Qt.alpha("#000000", 0.27)
                source: rect
            }
        }
    }
}
