import qs.Core
import qs.Bar.Content
import qs.Shared.Background
import qs.Core.Services
import QtQuick

Item {
    id: root

    visible: currentSubmap !== ""
    implicitWidth: content.implicitWidth + 16
    implicitHeight: 30

    readonly property string currentSubmap: HyprlandSubmap.activeSubmap

    SurfaceBackground {
        color: Appearance.md3.primary_container
        anchors.fill: parent
    }

    HyprlandSubmapContent {
        id: content

        anchors.centerIn: parent
        text: root.currentSubmap
    }

}
