import QtQuick
import qs.Core

Item {
    id: root
    property real value: 0.0   // 0–1
    property color accentColor: Appearance.md3.primary

    implicitWidth: 200
    implicitHeight: 6

    StyledProgressBar {
        value: root.value
        accentColor: root.accentColor
        barHeight: 5
        backgroundColor: Appearance.md3.surface_container
    }
}
