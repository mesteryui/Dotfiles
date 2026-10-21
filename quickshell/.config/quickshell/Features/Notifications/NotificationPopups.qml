pragma ComponentBehavior: Bound

import qs.Core
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var trackedNotifications

    anchors {
        top: true
        right: true
    }
    margins {
        top: 50
        right: 12
    }
    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight)
    // Sin toasts no hay nada que mostrar: mantener la superficie mapeada
    // (380x1) obligaba a Qt a mantener vivo un contexto GL extra.
    // trackedNotifications es un QAbstractListModel (UntypedObjectModel):
    // su lista JS está en .values; .length no existe y dejaba el toast oculto.
    visible: root.trackedNotifications.values.length > 0
    color: "transparent"
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand: el reply inline necesita foco Wayland solo al clicar el
    // campo. Con None (defecto) Qt pedía text-input en una surface sin
    // foco -> spam enableSurface al responder.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Appearance.spacing.medium

        Repeater {
            model: root.trackedNotifications

            delegate: NotificationToastCard {
                required property var modelData

                notification: modelData
            }
        }
    }
}
