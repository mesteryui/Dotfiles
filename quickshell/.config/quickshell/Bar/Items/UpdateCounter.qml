pragma ComponentBehavior: Bound

import qs.Core.Services as Services
import qs.Bar.Content
import qs.Panels.Updates
import QtQuick
import Quickshell

BarItem {
    id: root

    clickable: !root.service.updating && !root.service.checking
    horizontalPadding: 12
    scale: area.containsMouse ? 1.08 : 1

    readonly property var service: Services.UpdatesTracking
    visible: service.updateCount > 0 || service.checking

    onClicked: {
        // Si popupLoader todavía está en 'loading' (async) cuando
        // se hace click, acceder a .item fuerza el completado
        // síncrono automáticamente — no hace falta gestionarlo aquí.
        const w = popupLoader.item;
        if (w)
            w.visible = !w.visible;
    }

    LazyLoader {
        id: popupLoader

        // 'loading' construye el popup en segundo plano, en los huecos
        // entre frames, sin bloquear el hilo de UI al crear la barra.
        // 'active' (el original) fuerza carga síncrona inmediata y
        // bloqueante — mala idea para algo que no se ve hasta el click.
        loading: true

        component: UpdateList {
            id: popup
        }
    }

    UpdateCounterContent {
        id: content

        anchors.centerIn: parent
        service: root.service
    }
}
