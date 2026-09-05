import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

RowLayout {
    
    Repeater {
        model: Hyprland.workspaces
        delegate: WorkspaceButton {
            isActive: Hyprland.focusedWorkspace?.id === modelData.id
        }
    }
}
