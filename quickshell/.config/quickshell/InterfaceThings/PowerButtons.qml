import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../Services" as Services
import QtQuick.Layouts

MenuWindow {
    id: root
    visible: false
    
    // 5 botones de 100px + 4 espacios de 20px + 2 margenes de 20px = 620px
    implicitWidth: 620
    // 1 botón de 100px + 2 margenes de 20px = 140px
    implicitHeight: 140

    WlrLayershell.namespace: "logout_dialog"

    onVisibleChanged: {
        if (visible) {
            shutdownBtn.forceActiveFocus();
        }
    }

    IpcHandler {
        target: "ui.powermenu"
        function togglePowerMenu(): void {
            root.visible = !root.visible;
        }
    }

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        
        // MenuWindow ya tiene 12px de margen interno. 
        // Agregamos 8px más para llegar a los 20px uniformes.
        anchors.margins: 8
        spacing: 20

        GenericButton {
            id: shutdownBtn
            buttonText: Services.I18nService.getTranslation("power.shutdown")
            buttonIcon: "system-shutdown"
            command: "systemctl poweroff"
            accentColor: "#E53935"
            KeyNavigation.left: logoutBtn
            KeyNavigation.right: rebootBtn
            
            Layout.alignment: Qt.AlignCenter
        }
        
        GenericButton {
            id: rebootBtn
            buttonText: Services.I18nService.getTranslation("power.reboot")
            buttonIcon: "system-reboot"
            command: "systemctl reboot"
            accentColor: "#FB8C00"

            KeyNavigation.left: shutdownBtn
            KeyNavigation.right: suspendBtn
            
            Layout.alignment: Qt.AlignCenter
        }
        
        GenericButton {
            id: suspendBtn
            buttonText: Services.I18nService.getTranslation("power.suspend")
            buttonIcon: "system-suspend"
            command: "systemctl suspend"
            accentColor: Colors.primary

            KeyNavigation.left: rebootBtn
            KeyNavigation.right: lockBtn
            
            Layout.alignment: Qt.AlignCenter
        }
        
        GenericButton {
            id: lockBtn
            buttonText: Services.I18nService.getTranslation("power.lock")
            buttonIcon: "system-lock-screen"
            command: "pidof hyprlock || hyprlock"
            accentColor: Colors.primary

            KeyNavigation.left: suspendBtn
            KeyNavigation.right: logoutBtn
            
            Layout.alignment: Qt.AlignCenter
        }
        
        GenericButton {
            id: logoutBtn
            buttonText: Services.I18nService.getTranslation("power.logout")
            buttonIcon: "system-log-out"
            command: "hyprctl dispatch 'hl.dsp.exit()'"
            accentColor: Colors.secondary
            
            KeyNavigation.left: lockBtn
            KeyNavigation.right: shutdownBtn
            
            Layout.alignment: Qt.AlignCenter
        }
    }
}
