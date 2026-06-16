import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../Core"
import "../Components"
import "../Core/Services" as Services
import "../Features/Windows"
import "../Components/Interface"
import "."

MenuWindow {
    id: root
    visible: false

    menuWidth: 400
    menuHeight: 600

    WlrLayershell.namespace: "notification-center"

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
