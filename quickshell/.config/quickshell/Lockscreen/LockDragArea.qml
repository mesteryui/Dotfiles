// LockDragArea — zona de arrastre para despertar (swipe/clic).
// Extraído de LockScreenContent.qml. Expone dragDy/dragging y reset().
import QtQuick

MouseArea {
    id: root

    property bool isAwake: false

    signal wakeUp

    // Vuelve al reposo al dormir (antes lo hacía onIsAwakeChanged).
    function reset() {
        dragDy = 0;
    }

    anchors.fill: parent
    z: isAwake ? -1 : 1
    enabled: !isAwake
    hoverEnabled: false

    property real dragStartY: 0
    property real dragDy: 0
    property bool dragging: false

    onPressed: mouse => {
        dragStartY = mouse.y;
        dragDy = 0;
        dragging = true;
    }
    onPositionChanged: mouse => {
        if (dragging)
            dragDy = Math.max(0, dragStartY - mouse.y);
    }
    onReleased: mouse => {
        if (!dragging)
            return;
        dragging = false;
        const dy = Math.max(0, dragStartY - mouse.y);
        const isClick = dy < 12;
        const isSwipe = dy > 70;
        if (isClick || isSwipe) {
            // No se resetea dragDy aquí: dormido→despierto los bindings
            // ya ignoran el gesto y el reseteo provocaba un pulso
            // (preview→reposo→despierto) que se veía como parpadeo.
            // Se limpia al volver a dormir (ver onIsAwakeChanged).
            wakeUp();
        } else {
            dragDy = 0;
        }
    }
    onCanceled: {
        dragging = false;
        dragDy = 0;
    }
}
