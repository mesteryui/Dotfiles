pragma ComponentBehavior: Bound

import qs.Primitives
import qs.Shared.Background
import qs.Core
import qs.Core.Modules
import qs.Core.Services as Services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import M3Shapes

Scope {
    id: scope

    property bool shown: false

    function close() {
        scope.shown = false;
    }

    IpcHandler {
        target: "switcher"

        function toggle() {
            scope.shown = !scope.shown;
        }
    }
    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "windowSwitcher"
        // Literal a propósito: GlobalShortcut no admite cambios tras
        // crearse y un binding a I18nService se re-evalúa al cargar el
        // idioma ("cannot be modified after creation"). El resto de
        // atajos también usa literales sin traducir.
        description: "Toggle window switcher"
        onPressed: {
            scope.shown = !scope.shown;
        }
    }

    // LazyLoader: primera apertura asíncrona en gaps de frames y caché
    // después (reaperturas instantáneas). Como la ventana ya no se
    // destruye al cerrar, su visible va atado a scope.shown.
    LazyLoader {
        loading: scope.shown
        component: PanelWindow {
            id: root

            // ── Tokens locales (geometría del switcher) ──
            // cardWidth debe coincidir con el literal del delegado (Bound:
            // el delegado no ve este scope). cardSpacing va en ListView.spacing.
            readonly property int cardWidth: 140
            readonly property int cardSpacing: 8
            // Ancho de cada botón + spacing.
            readonly property int itemWidth: cardWidth + cardSpacing
            readonly property int listMargins: 12
            readonly property int edgeMargin: 16
            readonly property int footerSideMargin: 18
            readonly property int fadeWidth: 56
            readonly property int chevronSize: 28
            readonly property int chevronIconSize: 18
            // Máximo de botones visibles sin crecer el panel; a partir de
            // aquí la lista se navega (flechas, Tab, rueda).
            readonly property int maxVisibleItems: 4
            readonly property int panelHeight: 180
            readonly property int panelHeightOverflow: 198
            // Duraciones de animación (ms).
            readonly property int animFast: 150
            readonly property int animMed: 180
            readonly property int animMorph: 300

            // Las ventanas internas/dummy rara vez tienen appId/windowClass.
            function isRealToplevel(toplevel) {
                if (!toplevel)
                    return false;

                const appId = (toplevel.wayland ? toplevel.wayland.appId : "") || toplevel.windowClass || toplevel.initialClass;
                return appId !== undefined && appId !== "";
            }

            // Modelo ya filtrado: el ListView solo ve ventanas reales, así
            // que currentIndex/count/scroll cuadran sin saltar fantasmas.
            readonly property var realToplevels: Hyprland.toplevels.values.filter(root.isRealToplevel)
            readonly property int realWindowCount: realToplevels.length
            // Hay más ventanas de las que caben: mostrar ayudas de scroll
            // (fades laterales, chevrons y barra inferior).
            readonly property bool overflow: realWindowCount > maxVisibleItems

            // Con 0 ventanas se queda en el ancho de un único hueco (no
            // colapsa a 0). Crece hasta maxVisibleItems; a partir de ahí el
            // ancho se queda fijo y el ListView es quien se desplaza.
            readonly property int visibleItemCount: Math.min(Math.max(realWindowCount, 1), maxVisibleItems)

            implicitWidth: Math.min(screen.width * 0.9, listMargins * 2 + visibleItemCount * itemWidth - cardSpacing)
            // Altura extra para la barra de scroll/contador cuando hay overflow.
            implicitHeight: overflow ? panelHeightOverflow : panelHeight
            color: "transparent"

            // Atado al scope: el LazyLoader cachea la ventana entre aperturas.
            visible: scope.shown

            // Sale en el monitor enfocado, como el resto de overlays.
            screen: Screens.focusedScreen

            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore

            // Imprescindible en layer-shell: sin esto el teclado no llega nunca a la
            // surface (mismo pitfall que ya nos mordió con el app launcher).
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            HyprlandFocusGrab {
                windows: [root]
                active: root.visible
                // Cierra el scope (no solo la ventana): si no, el Loader
                // seguiría activo con `shown == true` e invisible.
                onCleared: {
                    if (scope.shown)
                        Qt.callLater(scope.close);
                }
            }

            // Selecciona en el ListView la ventana activa del compositor para
            // que al abrir el switcher ya aparezca resaltada por defecto.
            function selectActiveWindow() {
                const active = Hyprland.activeToplevel;
                if (!active) {
                    if (windowList.count > 0 && windowList.currentIndex < 0)
                        windowList.currentIndex = 0;
                    return;
                }
                const idx = root.realToplevels.indexOf(active);
                if (idx >= 0) {
                    windowList.currentIndex = idx;
                    windowList.positionViewAtIndex(idx, ListView.Center);
                } else if (windowList.count > 0 && windowList.currentIndex < 0) {
                    windowList.currentIndex = 0;
                }
            }

            Component.onCompleted: Qt.callLater(selectActiveWindow)

            // Con OnDemand nadie tiene el foco de teclado hasta que alguien lo pide
            // explícitamente. windowList.focus = true solo lo marca como candidato
            // dentro del focus scope; esto es lo que realmente empuja el foco a la
            // ventana cuando se abre.
            onVisibleChanged: {
                if (root.visible) {
                    // Diferido: el modelo se acaba de (re)asociar al abrir y
                    // positionViewAtIndex en el mismo tick reentra en el
                    // DelegateModel a medio resetear (SIGSEGV en setModel).
                    Qt.callLater(selectActiveWindow);
                    windowList.forceActiveFocus();
                }
            }

            // Fondo primero: si se declara después del ListView lo tapa por completo.
            PopupBackground {
                anchors.fill: parent
            }

            ListView {
                id: windowList

                anchors.fill: parent
                anchors.margins: root.listMargins
                // Reserva sitio abajo para la barra de scroll/contador.
                anchors.bottomMargin: root.overflow ? 30 : root.listMargins
                focus: true

                orientation: ListView.Horizontal
                clip: true
                spacing: root.cardSpacing
                boundsBehavior: Flickable.StopAtBounds

                // Hay contenido oculto a izquierda/derecha: alimenta los
                // fades, chevrons y la barra inferior.
                property bool canGoLeft: contentX > 1
                property bool canGoRight: contentX + width < contentWidth - 1

                // Modelo nulo con el switcher cerrado: la ventana se cachea
                // entre aperturas y los toplevels cambian constantemente en
                // background; con la vista suscrita, cada open/close de
                // ventana disparaba setModel sobre una vista oculta -> el
                // mismo SIGSEGV que ya vimos con el launcher por IPC.
                model: scope.shown ? root.realToplevels : null

                // Accessible va en un Item, no en la PanelWindow (ventana):
                // Qt avisa "must be attached to an object deriving from
                // Item or Action" si se pone en la ventana.
                Accessible.role: Accessible.Dialog
                Accessible.name: Services.I18nService.getTranslation("switcher.toggle", "Window switcher Toggle")
                Accessible.description: (currentIndex + 1) + " / " + count

                highlightMoveDuration: root.animFast
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: width
                highlight: Rectangle {
                    radius: Appearance.shape.small
                    color: Appearance.md3.primary
                    opacity: 0.15
                }

                WheelHandler {
                    orientation: Qt.Vertical
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const d = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                        windowList.contentX -= d;
                    }
                }

                Keys.onLeftPressed: event => {
                    windowList.cycle(-1);
                    event.accepted = true;
                }

                Keys.onRightPressed: event => {
                    windowList.cycle(1);
                    event.accepted = true;
                }

                Keys.onTabPressed: event => {
                    if (event.modifiers & Qt.ShiftModifier)
                        windowList.cycle(-1);
                    else
                        windowList.cycle(1);
                    event.accepted = true;
                }

                Keys.onBacktabPressed: event => {
                    windowList.cycle(-1);
                    event.accepted = true;
                }

                Keys.onEscapePressed: event => {
                    scope.close();
                    event.accepted = true;
                }

                Keys.onReturnPressed: windowList.activateCurrent()

                Keys.onEnterPressed: windowList.activateCurrent()

                function cycle(delta) {
                    const count = windowList.count;
                    if (count <= 0)
                        return;

                    let idx = windowList.currentIndex;
                    if (idx < 0)
                        idx = delta > 0 ? -1 : 0;

                    // El modelo ya está filtrado: vuelta circular directa.
                    idx = (idx + delta + count) % count;
                    windowList.currentIndex = idx;
                    windowList.positionViewAtIndex(idx, ListView.Contain);
                }

                function activateCurrent() {
                    const toplevel = windowList.currentItem?.modelData;
                    if (!toplevel)
                        return;

                    // Validación segura por si wayland es null
                    toplevel.wayland?.activate();

                    scope.close();
                }

                delegate: Item {
                    id: windowDelegate

                    required property var modelData
                    required property int index

                    // Bound: sin acceso a los ids exteriores; este 140 debe
                    // coincidir con root.cardWidth (ver comentario allí).
                    width: 140
                    height: ListView.view.height

                    Rectangle {
                        width: 140
                        height: parent.height
                        radius: Appearance.shape.small
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

                            // Contenedor expresivo del icono: morfea al seleccionar
                            // (Circle → Cookie9Sided), como el avatar del lockscreen.
                            // Se usa ListView.view (el delegate es Bound y no ve
                            // los ids exteriores).
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitWidth: 58
                                implicitHeight: 58

                                property bool isCurrent: ListView.view ? ListView.view.currentIndex === windowDelegate.index : false

                                MaterialShape {
                                    anchors.fill: parent
                                    shape: parent.isCurrent ? MaterialShape.Cookie9Sided : MaterialShape.Circle
                                    animationDuration: 300
                                    color: parent.isCurrent ? Appearance.md3.primary_container : Appearance.md3.surface_container_highest
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: parent.isCurrent ? 46 : 40
                                    source: {
                                        const tl = windowDelegate.modelData;
                                        if (!tl)
                                            return ""; // Protección contra null

                                        const appId = (tl.wayland ? tl.wayland.appId : "") || tl.windowClass || tl.initialClass;
                                        // Icons memoiza por appId: sin lookup repetido.
                                        return Icons.getAppIcon(appId, "application-x-executable");
                                    }

                                    Behavior on implicitSize {
                                        NumberAnimation { duration: 150 }
                                    }
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

            // ── Fades laterales: pista de que hay más ventanas ──
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: root.listMargins
                anchors.top: windowList.top
                anchors.bottom: windowList.bottom
                width: root.fadeWidth
                z: 5
                opacity: (root.overflow && windowList.canGoLeft) ? 1 : 0
                visible: opacity > 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Appearance.md3.surface
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animMed
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: root.listMargins
                anchors.top: windowList.top
                anchors.bottom: windowList.bottom
                width: root.fadeWidth
                z: 5
                opacity: (root.overflow && windowList.canGoRight) ? 1 : 0
                visible: opacity > 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Appearance.md3.surface
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animMed
                    }
                }
            }

            // ── Chevrons clicables para moverse entre ventanas ──
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: root.edgeMargin
                anchors.verticalCenter: windowList.verticalCenter
                width: root.chevronSize
                height: root.chevronSize
                radius: Appearance.shape.full
                z: 6
                opacity: (root.overflow && windowList.canGoLeft) ? 1 : 0
                visible: opacity > 0
                color: Appearance.md3.surface_container_highest
                border.color: Appearance.md3.outline_variant
                border.width: 1

                Accessible.role: Accessible.Button
                Accessible.name: Services.I18nService.getTranslation("switcher.previous", "Previous window")

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "chevron_left"
                    size: root.chevronIconSize
                    color: Appearance.md3.on_surface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: windowList.cycle(-1)
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animMed
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: root.edgeMargin
                anchors.verticalCenter: windowList.verticalCenter
                width: root.chevronSize
                height: root.chevronSize
                radius: Appearance.shape.full
                z: 6
                opacity: (root.overflow && windowList.canGoRight) ? 1 : 0
                visible: opacity > 0
                color: Appearance.md3.surface_container_highest
                border.color: Appearance.md3.outline_variant
                border.width: 1

                Accessible.role: Accessible.Button
                Accessible.name: Services.I18nService.getTranslation("switcher.next", "Next window")

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "chevron_right"
                    size: root.chevronIconSize
                    color: Appearance.md3.on_surface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: windowList.cycle(1)
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animMed
                    }
                }
            }

            // ── Barra inferior: progreso de scroll + contador ──
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: root.footerSideMargin
                anchors.rightMargin: root.footerSideMargin
                anchors.bottomMargin: root.listMargins
                height: root.listMargins
                z: 5
                visible: root.overflow

                Rectangle {
                    id: scrollTrack

                    anchors.left: parent.left
                    anchors.right: scrollCounter.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: height / 2
                    color: Appearance.md3.surface_container_highest

                    Rectangle {
                        // visibleArea refleja contentX/contentWidth sin
                        // cálculos manuales.
                        width: Math.max(24, parent.width * windowList.visibleArea.widthRatio)
                        height: parent.height
                        radius: height / 2
                        color: Appearance.md3.primary
                        x: windowList.visibleArea.xPosition * parent.width
                    }
                }

                StyledText {
                    id: scrollCounter

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (windowList.currentIndex + 1) + " / " + windowList.count
                    color: Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }
    }
}
