pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Primitives
import qs.Shared.Background
import qs.Core
import Quickshell.Io

PanelWindow {
    id: root

    implicitWidth: 720
    implicitHeight: 180
    color: "transparent"

    visible: false

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

    IpcHandler {
        target: "switcher"
        function toggle() {
            root.visible = !root.visible;
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

        // Horizontal desde el vamos: orientación + flow + rango de highlight
        // consistentes en el mismo eje, así no hay que retocar nada si el
        // día de mañana cambia el tamaño de los items.
        orientation: ListView.Horizontal

        clip: true
        spacing: 8
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

        // Muchos mice solo tienen rueda vertical: la remapeamos al eje
        // horizontal para que el scroll se sienta natural acá.
        WheelHandler {
            onWheel: event => windowList.contentX -= event.angleDelta.y
        }

        // --- Teclado ---
        Keys.onLeftPressed: windowList.decrementCurrentIndex()
        Keys.onRightPressed: windowList.incrementCurrentIndex()
        // Tab es señal propia del attached property Keys, separada de
        // Left/Right — así el switcher se navega igual que un Alt-Tab real,
        // sin pisar el focus-chain normal de Qt. Solo avanza; al llegar al
        // final, vuelve al principio (no hay reversa con Shift+Tab).
        Keys.onTabPressed: currentIndex === model.count - 1 ? currentIndex = 0 : incrementCurrentIndex()
        Keys.onBacktabPressed: currentIndex === 0 ? currentIndex = model.count - 1 : decrementCurrentIndex()
        Keys.onReturnPressed: windowList.activateCurrent()
        Keys.onEnterPressed: windowList.activateCurrent()

        function activateCurrent() {
            // currentItem es el delegate ya instanciado: leemos su
            // modelData directamente y nos evitamos tocar el ObjectModel
            // a mano (ObjectModel usa .values, no subscript por índice).
            const item = windowList.currentItem;
            if (item && item.modelData.wayland)
                item.modelData.wayland.activate();
            root.visible = false;
        }

        delegate: Rectangle {
            id: windowDelegate
            required property HyprlandToplevel modelData
            required property int index

            width: 140
            height: ListView.view.height
            radius: 12
            color: "transparent"
            //opacity: windowDelegate.modelData.activated ? 1 : 0.85

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
                        const wl = windowDelegate.modelData.wayland;
                        if (!wl)
                            return "";
                        const entry = DesktopEntries.byId(wl.appId);
                        return entry ? Quickshell.iconPath(entry.icon) : "";
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: windowDelegate.modelData.title
                    elide: Text.ElideRight
                    wrapMode: Text.WrapMode
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
