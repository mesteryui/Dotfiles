// --- AudioPopupContent ---
// Contenido del popup de audio: botón grande de mute/estado, selector de altavoz,
// slider de volumen de salida y slider de volumen de micrófono.
pragma ComponentBehavior: Bound
import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: 300
    implicitHeight: layout.implicitHeight

    // ── Navegación por teclado ──────────────────────────────────
    // Orden: bigButton → volumeSlider → sinks → micSlider → sources.
    // Tab/Shift+Tab funciona solo (activeFocusOnTab). Arriba/Abajo
    // mueve el foco entre secciones, Izq/Der ajusta el slider con foco,
    // Enter/Espacio activa, M alterna mute en los sliders.
    function focusDefault() {
        volumeSlider.forceActiveFocus();
    }

    function focusSink(index) {
        const item = sinkRepeater.itemAt(index);
        if (item)
            item.forceActiveFocus();
    }

    function focusSource(index) {
        const item = sourceRepeater.itemAt(index);
        if (item)
            item.forceActiveFocus();
    }

    function focusLastSinkOrVolume() {
        if (sinkRepeater.count > 0)
            root.focusSink(sinkRepeater.count - 1);
        else
            volumeSlider.forceActiveFocus();
    }

    function focusLastVisible() {
        if (sourceRepeater.count > 0)
            root.focusSource(sourceRepeater.count - 1);
        else if (sinkRepeater.count > 0)
            root.focusSink(sinkRepeater.count - 1);
        else
            micSlider.forceActiveFocus();
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 16

        // --- Botón grande de estado / mute ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                id: bigButton

                implicitWidth: 72
                implicitHeight: 72
                radius: Appearance.shape.large
                color: Services.AudioService.muted ? Appearance.md3.surface_container_highest : Appearance.md3.primary_container
                border.width: activeFocus ? 2 : 0
                border.color: Appearance.md3.primary
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: Services.AudioService.muted ? "Activar sonido" : "Silenciar"
                Accessible.description: Services.AudioService.muted ? "Silenciado" : Math.round(Services.AudioService.volume * 100) + "%"

                Keys.onReturnPressed: Services.AudioService.toggleMuted()
                Keys.onEnterPressed: Services.AudioService.toggleMuted()
                Keys.onSpacePressed: Services.AudioService.toggleMuted()
                Keys.onDownPressed: volumeSlider.forceActiveFocus()
                Keys.onUpPressed: root.focusLastVisible()

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: Services.AudioService.materialIcon
                    size: 36
                    color: Services.AudioService.muted ? Appearance.md3.on_surface_variant : Appearance.md3.on_primary_container
                }

                Rectangle {
                    id: bigButtonStateLayer

                    anchors.fill: parent
                    radius: parent.radius
                    color: Appearance.md3.on_surface
                    opacity: (bigButton.activeFocus || bigButtonMouse.containsMouse) ? 0.08 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }

                MouseArea {
                    id: bigButtonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: bigButton.forceActiveFocus()
                    onPressed: bigButton.forceActiveFocus()
                    onClicked: Services.AudioService.toggleMuted()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: Services.AudioService.muted ? "Silenciado" : Math.round(Services.AudioService.volume * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.bold: true
                    color: Appearance.md3.on_surface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Services.AudioService.deviceLabel(Services.AudioService.sink)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.md3.on_surface_variant
                    elide: Text.ElideRight
                }
            }
        }

        // --- Slider de volumen de salida ---
        ControlSlider {
            id: volumeSlider
            Layout.fillWidth: true
            iconName: Services.AudioService.materialIcon
            value: Services.AudioService.volume
            accentColor: Appearance.md3.primary
            accessibleName: "Volumen de salida"
            onMoved: val => Services.AudioService.setVolume(val)
            onIconClicked: Services.AudioService.toggleMuted()
            Keys.onUpPressed: bigButton.forceActiveFocus()
            Keys.onDownPressed: {
                if (sinkRepeater.count > 0)
                    root.focusSink(0);
                else
                    micSlider.forceActiveFocus();
            }
        }

        // --- Selector de altavoz ---
        StyledText {
            text: "Salida"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.bold: true
            color: Appearance.md3.on_surface_variant
            Layout.leftMargin: 4
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                id: sinkRepeater
                model: Services.AudioService.sinks

                delegate: Rectangle {
                    id: sinkRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: Services.AudioService.sink === sinkRow.modelData

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Appearance.shape.small
                    color: sinkRow.selected ? Appearance.md3.secondary_container : (activeFocus ? Qt.alpha(Appearance.md3.primary, 0.12) : "transparent")
                    border.width: activeFocus ? 2 : 0
                    border.color: Appearance.md3.primary
                    activeFocusOnTab: true

                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: sinkRow.selected
                    Accessible.name: Services.AudioService.deviceLabel(sinkRow.modelData)
                    Accessible.description: sinkRow.selected ? "Salida seleccionada" : "Salida disponible. Enter para seleccionar."

                    Keys.onReturnPressed: Services.AudioService.setSink(sinkRow.modelData)
                    Keys.onEnterPressed: Services.AudioService.setSink(sinkRow.modelData)
                    Keys.onSpacePressed: Services.AudioService.setSink(sinkRow.modelData)
                    Keys.onUpPressed: {
                        if (sinkRow.index > 0)
                            root.focusSink(sinkRow.index - 1);
                        else
                            volumeSlider.forceActiveFocus();
                    }
                    Keys.onDownPressed: {
                        if (sinkRow.index < sinkRepeater.count - 1)
                            root.focusSink(sinkRow.index + 1);
                        else
                            micSlider.forceActiveFocus();
                    }

                    Rectangle {
                        id: sinkStateLayer

                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.md3.on_surface
                        opacity: (sinkRow.activeFocus || sinkMouse.containsMouse) ? 0.08 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialIcon {
                            icon: "speaker"
                            size: Appearance.font.pixelSize.large
                            color: sinkRow.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Services.AudioService.deviceLabel(sinkRow.modelData)
                            elide: Text.ElideRight
                            color: sinkRow.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                        }

                        MaterialIcon {
                            visible: sinkRow.selected
                            icon: "check"
                            size: Appearance.font.pixelSize.large
                            color: Appearance.md3.on_secondary_container
                        }
                    }

                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: sinkRow.forceActiveFocus()
                        onPressed: sinkRow.forceActiveFocus()
                        onClicked: Services.AudioService.setSink(sinkRow.modelData)
                    }
                }
            }
        }

        // --- Divisor ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.md3.outline_variant
        }

        // --- Slider de micrófono ---
        StyledText {
            text: "Micrófono"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.bold: true
            color: Appearance.md3.on_surface_variant
            Layout.leftMargin: 4
        }

        ControlSlider {
            id: micSlider
            Layout.fillWidth: true
            iconName: Services.AudioService.micMaterialIcon
            value: Services.AudioService.micVolume
            accentColor: Appearance.md3.primary
            accessibleName: "Volumen del micrófono"
            onMoved: val => Services.AudioService.setMicVolume(val)
            onIconClicked: Services.AudioService.toggleMicMuted()
            Keys.onUpPressed: root.focusLastSinkOrVolume()
            Keys.onDownPressed: {
                if (sourceRepeater.count > 0)
                    root.focusSource(0);
                else
                    bigButton.forceActiveFocus();
            }
        }

        // --- Selector de micrófono ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                id: sourceRepeater
                model: Services.AudioService.sources

                delegate: Rectangle {
                    id: sourceRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: Services.AudioService.source === sourceRow.modelData

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Appearance.shape.small
                    color: sourceRow.selected ? Appearance.md3.secondary_container : (activeFocus ? Qt.alpha(Appearance.md3.primary, 0.12) : "transparent")
                    border.width: activeFocus ? 2 : 0
                    border.color: Appearance.md3.primary
                    activeFocusOnTab: true

                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: sourceRow.selected
                    Accessible.name: Services.AudioService.deviceLabel(sourceRow.modelData)
                    Accessible.description: sourceRow.selected ? "Micrófono seleccionado" : "Micrófono disponible. Enter para seleccionar."

                    Keys.onReturnPressed: Services.AudioService.setSource(sourceRow.modelData)
                    Keys.onEnterPressed: Services.AudioService.setSource(sourceRow.modelData)
                    Keys.onSpacePressed: Services.AudioService.setSource(sourceRow.modelData)
                    Keys.onUpPressed: {
                        if (sourceRow.index > 0)
                            root.focusSource(sourceRow.index - 1);
                        else
                            micSlider.forceActiveFocus();
                    }
                    Keys.onDownPressed: {
                        if (sourceRow.index < sourceRepeater.count - 1)
                            root.focusSource(sourceRow.index + 1);
                        else
                            bigButton.forceActiveFocus();
                    }

                    Rectangle {
                        id: sourceStateLayer

                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.md3.on_surface
                        opacity: (sourceRow.activeFocus || sourceMouse.containsMouse) ? 0.08 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialIcon {
                            icon: "mic"
                            size: Appearance.font.pixelSize.large
                            color: sourceRow.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Services.AudioService.deviceLabel(sourceRow.modelData)
                            elide: Text.ElideRight
                            color: sourceRow.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                        }

                        MaterialIcon {
                            visible: sourceRow.selected
                            icon: "check"
                            size: Appearance.font.pixelSize.large
                            color: Appearance.md3.on_secondary_container
                        }
                    }

                    MouseArea {
                        id: sourceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: sourceRow.forceActiveFocus()
                        onPressed: sourceRow.forceActiveFocus()
                        onClicked: Services.AudioService.setSource(sourceRow.modelData)
                    }
                }
            }
        }
    }
}
