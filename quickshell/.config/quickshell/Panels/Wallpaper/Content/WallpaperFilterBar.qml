// WallpaperFilterBar — fila de filtros del selector de fondos: tipo
// (todos/imágenes/vídeos) a la izquierda y color (grupos de hue, al estilo
// Ryoku) a la derecha. `host` es la raíz de WallpaperMenuContent:
// lee/escribe `typeFilter`/`colorFilter` y llama a `toggleColor`/`clearFilters`.
//
// La tira de color replica la de Ryoku: chip ALL + un swatch por grupo de hue
// presente (arcoíris calculado, neutro al final), selección única. Los colores
// de los swatches no usan tokens M3 a propósito: representan el color real de
// la pintura, ajeno al tema. Excepción intencionada y única, igual que el
// scrim monocromo sobre foto del carrusel.
pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var host

    readonly property var typeModel: [
        {
            "key": "all",
            "iconName": "apps",
            "labelKey": "wallpaper.filter.all",
            "fallback": "Todos"
        },
        {
            "key": "image",
            "iconName": "image",
            "labelKey": "wallpaper.filter.image",
            "fallback": "Imágenes"
        },
        {
            "key": "video",
            "iconName": "movie",
            "labelKey": "wallpaper.filter.video",
            "fallback": "Vídeos"
        }
    ]

    function label(key: string, fallback: string): string {
        return Services.I18nService?.getTranslation(key, fallback) ?? fallback;
    }

    // Etiqueta de la zona de color: mientras el primer escaneo está en vuelo
    // (y aún no hay datos) avisa, en vez de ofrecer un filtro que no filtra.
    function colorLabel(): string {
        const colorService = Services.WallpaperColorService;
        if (colorService.scanning && colorService.entries === 0)
            return root.label("wallpaper.filter.analyzing", "Analizando colores…");
        return root.label("wallpaper.filter.color", "Color");
    }

    // Nombre accesible de un grupo de color (id -> clave i18n).
    function colorName(id: int): string {
        const colorService = Services.WallpaperColorService;
        return root.label("wallpaper.color." + colorService.keys[id], colorService.names[id] ?? "");
    }

    spacing: Appearance.spacing.s

    // ── Tipo: Todos / Imágenes / Vídeos ─────────────────────────────────
    Row {
        Layout.alignment: Qt.AlignVCenter
        spacing: 6

        Repeater {
            model: root.typeModel

            delegate: Rectangle {
                id: typePill

                required property var modelData

                readonly property bool active: root.host.typeFilter === modelData.key
                // Sin soporte de vídeo (QtMultimedia ausente) el tipo "Vídeos"
                // no puede dar resultados: se atenúa en vez de mentir.
                readonly property bool unavailable: modelData.key === "video"
                                                    && Services.VideoSupport.settled &&
                                                    !Services.VideoSupport.available

                implicitWidth: typeRow.implicitWidth + 24
                implicitHeight: 32
                radius: Appearance.shape.full
                color: active ? Appearance.md3.secondary_container : Appearance.md3.surface_container_high
                opacity: unavailable ? Appearance.state.disabled : 1.0

                Accessible.role: Accessible.RadioButton
                Accessible.name: root.label(modelData.labelKey, modelData.fallback)
                Accessible.checked: active

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.motion.short3
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.motion.short3
                    }
                }

                M3StateLayer {
                    anchors.fill: parent
                    radius: typePill.radius
                    hovered: typeMouse.containsMouse
                    pressed: typeMouse.pressed
                    tint: typePill.active ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                }

                Row {
                    id: typeRow

                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: typePill.modelData.iconName
                        size: Appearance.typeScale.bodyLarge
                        color: typePill.active ? Appearance.md3.on_secondary_container :
                                                 Appearance.md3.on_surface_variant
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.label(typePill.modelData.labelKey, typePill.modelData.fallback)
                        font.pixelSize: Appearance.typeScale.titleSmall
                        color: typePill.active ? Appearance.md3.on_secondary_container :
                                                 Appearance.md3.on_surface_variant
                    }
                }

                MouseArea {
                    id: typeMouse

                    anchors.fill: parent
                    enabled: !typePill.unavailable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Sin forceActiveFocus a propósito: pulsar un filtro no
                    // debe robar el foco al carrusel (las flechas siguen
                    // navegando fondos justo después de filtrar).
                    onClicked: root.host.typeFilter = typePill.modelData.key
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
    }

    // ── Color (grupos de hue, selección única) ──────────────────────────
    StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: root.colorLabel()
        font.pixelSize: Appearance.typeScale.labelSmall
        color: Appearance.md3.on_surface_variant
    }

    Row {
        id: swatchRow

        Layout.alignment: Qt.AlignVCenter
        spacing: 4

        // Chip ALL: quita el filtro de color (grupo activo -1).
        Item {
            id: allChip

            readonly property bool active: root.host.colorFilter === -1

            implicitWidth: allText.implicitWidth + 20
            implicitHeight: 30

            Accessible.role: Accessible.RadioButton
            Accessible.name: root.label("wallpaper.filter.all", "Todos")
            Accessible.checked: allChip.active

            Rectangle {
                anchors.fill: parent
                radius: Appearance.shape.full
                color: allChip.active ? Appearance.md3.secondary_container :
                                        Appearance.md3.surface_container_high
                border.width: allChip.active ? 0 : 1
                border.color: Qt.alpha(Appearance.md3.on_surface, 0.18)

                StyledText {
                    id: allText

                    anchors.centerIn: parent
                    text: root.label("wallpaper.filter.all", "Todos")
                    font.pixelSize: Appearance.typeScale.labelSmall
                    color: allChip.active ? Appearance.md3.on_secondary_container :
                                            Appearance.md3.on_surface_variant
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.clearColor()
            }
        }

        Repeater {
            model: Services.WallpaperColorService.presentGroups

            delegate: Item {
                id: swatch

                required property int modelData

                readonly property bool active: root.host.colorFilter === modelData
                readonly property color paint: Services.WallpaperColorService.swatch(modelData)

                implicitWidth: 30
                implicitHeight: 30

                Accessible.role: Accessible.RadioButton
                Accessible.name: root.colorName(modelData)
                Accessible.checked: active

                // Anillo de selección (fuera del swatch, para no perder el
                // color real al marcarlo).
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Appearance.md3.on_surface
                    visible: swatch.active
                }

                Rectangle {
                    id: dot

                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: width / 2
                    color: swatch.paint
                    border.width: 1
                    border.color: Qt.alpha(Appearance.md3.on_surface, 0.25)
                    scale: swatchMouse.containsMouse ? 1.12 : 1.0

                    Behavior on scale {
                        SpringAnimation {
                            spring: Appearance.motion.springSnappy.spring
                            damping: Appearance.motion.springSnappy.damping
                            mass: Appearance.motion.springSnappy.mass
                            epsilon: 0.005
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "check"
                        size: 14
                        color: Services.WallpaperColorService.swatchInk(swatch.modelData)
                        visible: swatch.active
                    }
                }

                MouseArea {
                    id: swatchMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.host.toggleColor(swatch.modelData)
                }
            }
        }
    }

    // ── Limpiar filtros ─────────────────────────────────────────────────
    Rectangle {
        id: clearChip

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: clearRow.implicitWidth + 20
        implicitHeight: 30
        radius: Appearance.shape.full
        color: Appearance.md3.surface_container_high
        visible: root.host.filtersActive
        // Sin esto el RowLayout reserva el ancho aunque esté invisible.
        Layout.preferredWidth: visible ? implicitWidth : 0

        M3StateLayer {
            anchors.fill: parent
            radius: clearChip.radius
            hovered: clearMouse.containsMouse
            pressed: clearMouse.pressed
        }

        Row {
            id: clearRow

            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "filter_alt_off"
                size: Appearance.typeScale.bodyMedium
                color: Appearance.md3.on_surface_variant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label("wallpaper.filter.clear", "Limpiar")
                font.pixelSize: Appearance.typeScale.labelMedium
                color: Appearance.md3.on_surface_variant
            }
        }

        MouseArea {
            id: clearMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.host.clearFilters()
        }
    }
}
