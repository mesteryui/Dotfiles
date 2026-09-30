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
 *
 * `firstRowIndex`  – global flat-list index of this card's first bind row.
 * `activeRowIndex` – global flat-list index currently highlighted by keyboard.
 */
Item {
    id: root

    Accessible.role: Accessible.Grouping
    Accessible.name: category

    required property string category
    required property var binds // array of { mods, keyLabel, label, repeat, searchText }
    /// Global flat-list index of the first bind in this card.
    property int firstRowIndex: 0
    /// Global flat-list index that is currently keyboard-focused.
    property int activeRowIndex: -1
    /// Reference to the Flickable showing the cards (set by Cheatsheet.qml).
    property var flickRef: null
    /// Animated scroll helper from the sheet, signature scrollTo(y).
    property var scrollToFunc: null

    /// Emitted with a row's global flat-list index when the mouse hovers it,
    /// so the parent can fold mouse and keyboard navigation into one
    /// activeRowIndex instead of two disconnected highlight states.
    signal rowHovered(int globalIndex)

    readonly property int cardPadding: 20

    /// Scrolls just enough to make row `bindIdx` fully visible.
    /// Uses the delegate's real mapped coordinates instead of estimated
    /// heights — wrapped descriptions used to throw the math off and the
    /// keyboard selection ended up out of view.
    function ensureRowVisible(bindIdx) {
        const row = rowsRepeater.itemAt(bindIdx);
        if (!row || !flickRef || !flickRef.contentItem || !scrollToFunc)
            return;
        const p = row.mapToItem(flickRef.contentItem, 0, 0);
        const viewTop = flickRef.contentY;
        const viewBottom = viewTop + flickRef.height;
        if (p.y < viewTop - 1) {
            scrollToFunc(p.y - 8);
        } else if (p.y + row.height > viewBottom + 1) {
            scrollToFunc(p.y + row.height - flickRef.height + 8);
        }
    }

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

            spacing: Appearance.spacing.xs

            // Título de categoría con StyledText de Primitives
            StyledText {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                text: root.category
                color: Appearance.md3.primary
                font.pixelSize: Appearance.typeScale.titleSmall
                font.variableAxes: ({
                        "wght": 650,
                        "wdth": 100
                    })
            }

            Repeater {
                id: rowsRepeater

                model: root.binds
                delegate: CheatsheetKeybindRow {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true

                    bind: modelData
                    highlighted: (root.firstRowIndex + index) === root.activeRowIndex
                    onHoverEntered: root.rowHovered(root.firstRowIndex + index)
                }
            }
        }
    }
}
