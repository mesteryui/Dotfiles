import QtQuick
import qs.Panels.Updates
// Orquestador del popup de actualizaciones.
// No tiene lógica visual propia — solo ensambla los tres Wrappers.
Item {
    id: root

    signal updateRequested()

    implicitHeight: header.implicitHeight
                  + packages.implicitHeight
                  + footer.implicitHeight

    // ── Cabecera ─────────────────────────────────────────────
    UpdateListHeader {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
    }

    // ── Lista de paquetes ────────────────────────────────────
    UpdateListPackages {
        id: packages
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: footer.top
        }
    }

    // ── Pie ──────────────────────────────────────────────────
    UpdateListFooter {
        id: footer
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        onUpdateRequested: root.updateRequested()
    }
}
