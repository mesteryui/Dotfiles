// --- SettingsPanelContent.qml ---
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Core.Services as Services
import qs.Primitives
import qs.Core

Item {
    id: root

    property int currentTab: 0

    // ── Componentes locales base corregidos ─────────────────────────
    component SectionCard: M3Card {
        id: card
        property string title: ""
        default property alias rows: inner.data

        Layout.fillWidth: true
        padding: 16
        radius: Appearance.shape.large
        color: Appearance.md3.surface_container_high

        content: ColumnLayout {
            id: inner
            width: parent.width
            spacing: 14

            StyledText {
                text: card.title
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Medium
                font.variableAxes: Appearance.font.variableAxes.title
                color: Appearance.md3.primary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }

    component FieldLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.md3.on_surface_variant
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    component TextRow: ColumnLayout {
        id: textRow
        property string label: ""
        property string value: ""
        signal edited(string text)

        Layout.fillWidth: true
        spacing: 4

        FieldLabel {
            text: textRow.label
        }
        MaterialTextField {
            Layout.fillWidth: true
            text: textRow.value
            onEditingFinished: textRow.edited(text)
        }
    }

    component ChoiceRow: ColumnLayout {
        id: choiceRow
        property string label: ""
        property string value: ""
        property var choicesModel: []
        signal chosen(string value)

        Layout.fillWidth: true
        spacing: 6

        FieldLabel {
            text: choiceRow.label
        }

        Flow {
            id: flowWrap
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: choiceRow.choicesModel
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool selected: modelData.value === choiceRow.value

                    implicitWidth: chipLabel.implicitWidth + 24
                    implicitHeight: 32
                    radius: Appearance.shape.full
                    color: chip.selected ? Appearance.md3.primary_container : Appearance.md3.surface_container_highest

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.md3.on_surface
                        opacity: chipArea.pressed ? 0.12 : (chipArea.containsMouse ? 0.08 : 0.0)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    StyledText {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData.text
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: chip.selected ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                    }

                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: choiceRow.chosen(chip.modelData.value)
                    }
                }
            }
        }
    }

    component SidebarTab: Rectangle {
        id: tabBtn
        property string iconName: ""
        property string title: ""
        property string description: ""
        property bool selected: false
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 60
        radius: Appearance.shape.large
        color: selected ? Appearance.md3.secondary_container : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Appearance.md3.on_surface
            opacity: tabArea.pressed ? 0.12 : (tabArea.containsMouse && !tabBtn.selected ? 0.08 : 0.0)
            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            StyledText {
                text: tabBtn.iconName
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: tabBtn.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    text: tabBtn.title
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: tabBtn.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                StyledText {
                    text: tabBtn.description
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: tabBtn.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        MouseArea {
            id: tabArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tabBtn.clicked()
        }
    }

    function toSlider(val, min, max) {
        return Math.max(0, Math.min(1, (val - min) / (max - min)));
    }
    function fromSlider(pos, min, max, decimals) {
        const real = min + pos * (max - min);
        const f = Math.pow(10, decimals ?? 0);
        return Math.round(real * f) / f;
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // 1. BARRA LATERAL IZQUIERDA (Ancho compacto y proporcionado)
        ColumnLayout {
            id: sidebar
            Layout.preferredWidth: 150
            Layout.maximumWidth: 150
            Layout.fillHeight: true
            spacing: 6

            StyledText {
                text: "Ajustes"
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Medium
                font.variableAxes: Appearance.font.variableAxes.title
                color: Appearance.md3.on_surface
                Layout.bottomMargin: 8
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            SidebarTab {
                iconName: "palette"
                title: "Interfaz"
                description: "Apariencia"
                selected: root.currentTab === 0
                onClicked: root.currentTab = 0
            }
            SidebarTab {
                iconName: "display_settings"
                title: "Pantalla"
                description: "Bloqueo y luz"
                selected: root.currentTab === 1
                onClicked: root.currentTab = 1
            }
            SidebarTab {
                iconName: "partly_cloudy_day"
                title: "Entorno"
                description: "Clima y avisos"
                selected: root.currentTab === 2
                onClicked: root.currentTab = 2
            }
            SidebarTab {
                iconName: "settings"
                title: "Sistema"
                description: "Idioma y updates"
                selected: root.currentTab === 3
                onClicked: root.currentTab = 3
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // 2. CONTENIDO DE LAS PESTAÑAS (STACKLAYOUT)
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentTab

            // ── PESTAÑA 0: INTERFAZ ──
            TabFlickable {
                SectionCard {
                    title: "Apariencia"

                    ControlToggle {
                        label: "Modo oscuro"
                        stateText: Services.ConfigService.configs.appearence.darkMode ? "Activado" : "Desactivado"
                        iconName: "dark_mode"
                        active: Services.ConfigService.configs.appearence.darkMode
                        onToggled: Services.ConfigService.configs.appearence.darkMode = !Services.ConfigService.configs.appearence.darkMode
                    }

                    ChoiceRow {
                        label: "Esquema de color (matugen)"
                        value: Services.ConfigService.configs.appearence.matugen.type
                        choicesModel: [
                            {
                                value: "scheme-tonal-spot",
                                text: "Tonal Spot"
                            },
                            {
                                value: "scheme-content",
                                text: "Content"
                            },
                            {
                                value: "scheme-expressive",
                                text: "Expressive"
                            },
                            {
                                value: "scheme-fidelity",
                                text: "Fidelity"
                            },
                            {
                                value: "scheme-fruit-salad",
                                text: "Fruit Salad"
                            },
                            {
                                value: "scheme-monochrome",
                                text: "Monochrome"
                            },
                            {
                                value: "scheme-neutral",
                                text: "Neutral"
                            },
                            {
                                value: "scheme-rainbow",
                                text: "Rainbow"
                            },
                            {
                                value: "scheme-vibrant",
                                text: "Vibrant"
                            }
                        ]
                        onChosen: val => Services.ConfigService.configs.appearence.matugen.type = val
                    }

                    TextRow {
                        label: "Fuente principal (sans)"
                        value: Services.ConfigService.configs.appearence.fontSans
                        onEdited: text => Services.ConfigService.configs.appearence.fontSans = text
                    }
                    TextRow {
                        label: "Fuente monoespaciada"
                        value: Services.ConfigService.configs.appearence.monospace
                        onEdited: text => Services.ConfigService.configs.appearence.monospace = text
                    }
                    TextRow {
                        label: "Fuente de lectura"
                        value: Services.ConfigService.configs.appearence.reading
                        onEdited: text => Services.ConfigService.configs.appearence.reading = text
                    }
                    TextRow {
                        label: "Fuente expresiva"
                        value: Services.ConfigService.configs.appearence.expressive
                        onEdited: text => Services.ConfigService.configs.appearence.expressive = text
                    }
                }

                SectionCard {
                    title: "Barra"

                    ChoiceRow {
                        label: "Posición"
                        value: Services.ConfigService.configs.bar.position
                        choicesModel: [
                            {
                                value: "top",
                                text: "Arriba"
                            },
                            {
                                value: "bottom",
                                text: "Abajo"
                            }
                        ]
                        onChosen: val => Services.ConfigService.configs.bar.position = val
                    }

                    ControlSlider {
                        Layout.fillWidth: true
                        label: "Altura"
                        iconName: "height"
                        value: root.toSlider(Services.ConfigService.configs.bar.height, 24, 64)
                        valueText: Services.ConfigService.configs.bar.height + " px"
                        onMoved: val => Services.ConfigService.configs.bar.height = root.fromSlider(val, 24, 64)
                    }

                    ChoiceRow {
                        label: "Estilo de espacios de trabajo"
                        value: Services.ConfigService.configs.bar.workspaceButtonType
                        choicesModel: [
                            {
                                value: "numbers",
                                text: "Números"
                            },
                            {
                                value: "kanji",
                                text: "Kanji"
                            },
                            {
                                value: "circles",
                                text: "Círculos"
                            }
                        ]
                        onChosen: val => Services.ConfigService.configs.bar.workspaceButtonType = val
                    }
                    ChoiceRow {
                        label: "Tipo de barra"
                        value: Services.ConfigService.configs.bar.barType
                        choicesModel: [
                            {
                                value: "floating",
                                text: "Flotante"
                            },
                            {
                                value: "full_hug",
                                text: "Completa (Full hug)"
                            },
                            {
                                value: "partial_hug",
                                text: "Parcial (Partial hug)"
                            },
                            {
                                value: "no_floating",
                                text: "No flotante"
                            }
                        ]
                        onChosen: val => Services.ConfigService.configs.bar.barType = val
                    }
                }
                Item {
                    Layout.preferredHeight: 8
                }
            }

            // ── PESTAÑA 1: PANTALLA ──
            TabFlickable {
                SectionCard {
                    title: "Pantalla de bloqueo"

                    ControlToggle {
                        label: "Usar fondo de pantalla"
                        stateText: Services.ConfigService.configs.lockscreen.useWallpaper ? "Activado" : "Desactivado"
                        iconName: "wallpaper"
                        active: Services.ConfigService.configs.lockscreen.useWallpaper
                        onToggled: Services.ConfigService.configs.lockscreen.useWallpaper = !Services.ConfigService.configs.lockscreen.useWallpaper
                    }

                    ControlSlider {
                        Layout.fillWidth: true
                        label: "Nivel de desenfoque"
                        iconName: "blur_on"
                        value: root.toSlider(Services.ConfigService.configs.lockscreen.blurLevel, 0.0, 3.0)
                        valueText: Services.ConfigService.configs.lockscreen.blurLevel.toFixed(1) + "x"
                        onMoved: val => Services.ConfigService.configs.lockscreen.blurLevel = root.fromSlider(val, 0.0, 3.0, 2)
                    }
                }

                SectionCard {
                    title: "Luz nocturna"

                    ControlSlider {
                        Layout.fillWidth: true
                        label: "Temperatura de color"
                        iconName: "thermostat"
                        value: root.toSlider(Services.ConfigService.configs.nightLight.temperature, 1000, 6500)
                        valueText: Services.ConfigService.configs.nightLight.temperature + " K"
                        onMoved: val => Services.ConfigService.configs.nightLight.temperature = root.fromSlider(val, 1000, 6500)
                    }

                    ControlSlider {
                        Layout.fillWidth: true
                        label: "Gamma"
                        iconName: "exposure"
                        value: root.toSlider(Services.ConfigService.configs.nightLight.gamma, 0, 100)
                        valueText: Services.ConfigService.configs.nightLight.gamma + "%"
                        onMoved: val => Services.ConfigService.configs.nightLight.gamma = root.fromSlider(val, 0, 100)
                    }
                }
                Item {
                    Layout.preferredHeight: 8
                }
            }

            // ── PESTAÑA 2: ENTORNO ──
            TabFlickable {
                SectionCard {
                    title: "Clima"

                    ControlToggle {
                        label: "Ubicación automática"
                        stateText: Services.ConfigService.configs.weather.autoLocation ? "Activado" : "Desactivado"
                        iconName: "my_location"
                        active: Services.ConfigService.configs.weather.autoLocation
                        onToggled: Services.ConfigService.configs.weather.autoLocation = !Services.ConfigService.configs.weather.autoLocation
                    }

                    TextRow {
                        label: "Ciudad"
                        value: Services.ConfigService.configs.weather.city
                        onEdited: text => Services.ConfigService.configs.weather.city = text
                        enabled: !Services.ConfigService.configs.weather.autoLocation
                        opacity: enabled ? 1.0 : 0.45
                    }

                    ControlSlider {
                        Layout.fillWidth: true
                        label: "Frecuencia de actualización"
                        iconName: "refresh"
                        value: root.toSlider(Services.ConfigService.configs.weather.reloadTime, 1, 60)
                        valueText: Services.ConfigService.configs.weather.reloadTime + " min"
                        onMoved: val => Services.ConfigService.configs.weather.reloadTime = root.fromSlider(val, 1, 60)
                    }
                }

                SectionCard {
                    title: "Notificaciones"

                    ControlSlider {
                        Layout.fillWidth: true
                        label: "Tiempo de espera"
                        iconName: "notifications"
                        value: root.toSlider(Services.ConfigService.configs.notifications.timeout, 1, 30)
                        valueText: Services.ConfigService.configs.notifications.timeout + " s"
                        onMoved: val => Services.ConfigService.configs.notifications.timeout = root.fromSlider(val, 1, 30)
                    }
                }
                Item {
                    Layout.preferredHeight: 8
                }
            }

            // ── PESTAÑA 3: SISTEMA ──
            TabFlickable {
                SectionCard {
                    title: "Idioma"

                    TextRow {
                        label: "Código de idioma (locale)"
                        value: Services.ConfigService.configs.language
                        onEdited: text => Services.ConfigService.configs.language = text
                    }
                }

                SectionCard {
                    title: "Actualizaciones"

                    ControlSlider {
                        Layout.fillWidth: true
                        label: "Frecuencia de comprobación"
                        iconName: "update"
                        value: root.toSlider(Services.ConfigService.configs.updates.countTime, 5, 180)
                        valueText: Services.ConfigService.configs.updates.countTime + " min"
                        onMoved: val => Services.ConfigService.configs.updates.countTime = root.fromSlider(val, 5, 180)
                    }

                    TextRow {
                        label: "Comando"
                        value: Services.ConfigService.configs.updates.command
                        onEdited: text => Services.ConfigService.configs.updates.command = text
                    }
                }
                Item {
                    Layout.preferredHeight: 8
                }
            }
        }
    }

    // Componente auxiliar interno para evitar repetir código en cada Flickable de pestaña
    component TabFlickable: Flickable {
        id: tabFlick
        default property alias colData: tabCol.data
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: tabCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StyledScrollBar {}

        ColumnLayout {
            id: tabCol
            width: parent.width
            spacing: 14
        }
    }
}
