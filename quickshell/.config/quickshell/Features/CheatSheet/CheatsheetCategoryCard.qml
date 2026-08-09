pragma ComponentBehavior: Bound
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

/**
 * CheatsheetCategoryCard
 * ------------------------
 * One category block, e.g. "Window Management" with its list of binds.
 * Uses M3Card from Primitives for the surface + shadow, keeping the pattern
 * consistent with the rest of the shell (panels, popups, etc.).
 *
 * Height is driven by the content ColumnLayout, with 20 px top/bottom padding
 * (same rhythm as the rest of the cards in the shell).
 */
Item {
    id: root

    required property string category
    required property var binds // array of { mods, keyLabel, label, repeat, searchText }

    readonly property int cardPadding: 20

    implicitWidth: 360
    // Height = content + top/bottom padding. M3Card fills us, we size ourselves.
    implicitHeight: content.implicitHeight + root.cardPadding * 2

    M3Card {
        id: card
        anchors.fill: parent

        ColumnLayout {
            id: content
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: root.cardPadding
                leftMargin: root.cardPadding
                rightMargin: root.cardPadding
            }
            spacing: 4

            // Título de categoría con StyledText de Primitives
            StyledText {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                text: root.category
                color: Appearance.md3.primary
                font.pixelSize: Appearance.font.pixelSize.small
                font.variableAxes: ({ "wght": 650, "wdth": 100 })
            }

            Repeater {
                model: root.binds
                delegate: CheatsheetKeybindRow {
                    required property var modelData
                    Layout.fillWidth: true
                    bind: modelData
                }
            }
        }
    }
}
