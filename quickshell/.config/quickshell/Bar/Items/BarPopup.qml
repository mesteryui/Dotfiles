pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// BarPopup — LazyLoader de popup de barra con descarga diferida.
//
// Carga asíncrona solo al abrir o pulsar (el hover no precarga). La gracia
// mantiene vivo un popup que ya se cargó, pero nunca inicia una carga por sí
// sola: si `active` es false, no toca `.item` ni arranca el timer.
//
// Mientras carga no se lee `.item`: `active` solo es true cuando el popup
// está completamente instanciado. `syncVisible()` es el único sitio que
// escribe `visible`. El popup cargado debe ser un BarPopupWindow (expone
// `visible`/`anchorItem`).
LazyLoader {
    id: root

    property Item anchorItem: null
    property bool hovered: false
    property bool pressed: false
    // Estado lógico de apertura; la visibilidad real la aplica syncVisible().
    property bool opened: false
    property int graceMs: 1200

    // Retiene un popup ya cargado tras cerrarse. Abrir o pulsar son los
    // únicos disparadores de carga.
    property bool _graceHold: false

    property Timer graceTimer: Timer {
        interval: root.graceMs
        repeat: false
        onTriggered: {
            if (!root.opened && !root.pressed && !root.hovered)
                root._graceHold = false;
        }
    }

    property Connections itemConnections: Connections {
        function onVisibleChanged() {
            // qmllint disable missing-property
            if (root.active && root.opened && !root.item.visible)
                root.opened = false;
            // qmllint enable missing-property
        }

        target: root.active ? root.item : null
        ignoreUnknownSignals: true
    }

    function toggle(): void {
        root.opened = !root.opened;
    }

    // Única escritura de `visible`; nunca toca .item antes de estar cargado.
    function syncVisible(): void {
        if (!root.active)
            return;
        // qmllint disable missing-property
        root.item.visible = root.opened;
        // qmllint enable missing-property
    }

    // Decide si la gracia debe retener el popup. No carga nada: con
    // active=false sale sin tocar .item ni el timer.
    function refreshGrace(): void {
        root.graceTimer.stop();

        if (!root.active) {
            root._graceHold = false;
            return;
        }

        // Abierto o pulsado ya lo mantienen activo por sí mismos.
        if (root.opened || root.pressed) {
            root._graceHold = false;
            return;
        }

        // Cursor encima: conservarlo cargado sin consumir la gracia.
        root._graceHold = true;
        if (!root.hovered)
            root.graceTimer.restart();
    }

    activeAsync: root.opened || root.pressed || root._graceHold

    onOpenedChanged: {
        root.syncVisible();
        root.refreshGrace();
    }

    onPressedChanged: root.refreshGrace()
    onHoveredChanged: root.refreshGrace()

    onActiveChanged: {
        if (!root.active) {
            root.graceTimer.stop();
            root._graceHold = false;
            return;
        }
        root.syncVisible();
        root.refreshGrace();
    }

    onItemChanged: {
        if (!root.active)
            return;
        // qmllint disable missing-property
        if (root.anchorItem)
            root.item.anchorItem = root.anchorItem;
        // qmllint enable missing-property
        root.syncVisible();
    }
}
