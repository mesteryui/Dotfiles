import QtQuick
import qs.Core
import qs.Bar.Content
import qs.Bar
import qs.Core.Services
Item {
    id: root
    visible: currentSubmap !== ""
    implicitWidth: content.implicitWidth + 16
    implicitHeight: 30
    
    readonly property string currentSubmap: HyprlandSubmap.activeSubmap
    
    BarBackground {
        color: Appearance.md3.primary_container
        anchors.fill: parent
    }
    
    HyprlandSubmapContent {
        id: content
        anchors.centerIn: parent
        text: root.currentSubmap
    }
    
}
