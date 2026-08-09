pragma ComponentBehavior: Bound
import qs.Core
import qs.Primitives
import QtQuick

/**
 * CheatsheetKeyChip
 * ------------------
 * A single key/modifier chip, e.g. "Super", "Shift", "Q".
 * Pure presentational — no interaction, so no state layer needed.
 *
 * Uses `surface_container_highest` so it stands out from the card background
 * (`surface_container_high`) and reads more like a physical keyboard key.
 */
Item {
    id: root

    required property string label

    implicitWidth: Math.max(30, label_text.implicitWidth + 18)
    implicitHeight: 26

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.shape.small  // shape token "small" = 12
        color: Appearance.md3.surface_container_highest
        border.width: 1
        border.color: Appearance.md3.outline_variant
    }

    StyledText {
        id: label_text
        anchors.centerIn: parent
        text: root.label
        color: Appearance.md3.on_surface
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.variableAxes: ({ "wght": 550, "wdth": 100 })
    }
}
