// SettingsSwitchRow — fila-switch M3 (switch list-item).
// Extraído de SettingsPanelContent.qml para partir sus ~950 líneas.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Item {
    id: switchRow

    property string label: ""
    property string stateText: ""
    property string iconName: ""
    property bool checked: false
    property bool enable: true

    signal toggled()

    Layout.fillWidth: true
    // Spec M3 list-item de dos líneas (siempre hay stateText): 72dp.
    implicitHeight: 72

    activeFocusOnTab: true

    Accessible.role: Accessible.CheckBox
    Accessible.checked: switchRow.checked
    Accessible.name: switchRow.label
    Accessible.description: switchRow.stateText

    Keys.onSpacePressed: { if (switchRow.enable) switchRow.toggled(); }
    Keys.onReturnPressed: { if (switchRow.enable) switchRow.toggled(); }
    Keys.onEnterPressed: { if (switchRow.enable) switchRow.toggled(); }

    opacity: switchRow.enable ? 1.0 : Appearance.state.disabled

    Behavior on opacity { NumberAnimation { duration: Appearance.motion.short3 } }

    // State layer de fila: pastilla redondeada al contenedor de la
    // tarjeta (el rectángulo a sangre no queda bien aquí).
    M3StateLayer {
        anchors.fill: parent
        anchors.margins: 2
        radius: Appearance.shape.small
        hovered: rowMouse.containsMouse || switchRow.activeFocus
        pressed: rowMouse.pressed
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: Appearance.spacing.l

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            icon: switchRow.iconName
            size: 24
            color: Appearance.md3.on_surface_variant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: switchRow.label
                font.pixelSize: Appearance.typeScale.titleSmall
                color: Appearance.md3.on_surface
                elide: Text.ElideRight
            }

            StyledText {
                visible: switchRow.stateText !== ""
                Layout.fillWidth: true
                text: switchRow.stateText
                font.pixelSize: Appearance.typeScale.labelSmall
                color: Appearance.md3.on_surface_variant
                elide: Text.ElideRight
            }
        }

        ControlSwitch {
            Layout.alignment: Qt.AlignVCenter
            checked: switchRow.checked
            interactive: false
            enable: switchRow.enable
        }
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: switchRow.enable
        cursorShape: Qt.PointingHandCursor
        onPressed: switchRow.forceActiveFocus()
        onClicked: switchRow.toggled()
    }
}
