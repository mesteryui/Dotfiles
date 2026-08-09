import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    
    Repeater {
        model: Hyprland.workspaces
        delegate: WorkspaceButton {
            isActive: Hyprland.focusedWorkspace?.id === modelData.id
        }
    }
}
