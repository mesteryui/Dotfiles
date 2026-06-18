import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Core
import qs.Components
import qs.Core.Services as Services
import qs.Features.Windows
import qs.Components.Interface

MenuWindow {
    id: root
    visible: false

    implicitWidth: 400
    implicitHeight: 600

    WlrLayershell.namespace: "notification-center"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        right: true
    }
    margins {
        top: 48
        right: 12
    }

    // ── IPC toggle ────────────────────────────────────────────────────────
    // NOTA: target "ui.notification-center" distinto del popup panel
    IpcHandler {
        target: "ui.notification-center"
        function toggleNotificationCenter(): void {
            root.visible = !root.visible
        }
    }

    NotificationCenter {
        anchors.fill: parent
        anchors.margins: 12
    }
}
