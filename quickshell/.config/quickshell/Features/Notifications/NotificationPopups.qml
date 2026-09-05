pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services
import qs.Primitives
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
    color: "transparent"
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    ColumnLayout {
        id: column

        width: parent.width
        spacing: 12

        Repeater {
            model: root.trackedNotifications

            delegate: NotificationToastCard {
                required property var modelData

                notification: modelData
            }
        }
    }
}
