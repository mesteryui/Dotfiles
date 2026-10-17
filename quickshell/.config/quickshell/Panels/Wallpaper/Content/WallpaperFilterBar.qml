// WallpaperFilterBar — fila de filtros del selector de fondos: tipo
// (todos/imágenes/vídeos) a la izquierda y color dominante (swatches
// multi-selección) a la derecha. `host` es la raíz de WallpaperMenuContent:
// lee/escribe `typeFilter`/`toneFilter` y llama a `toggleTone`/`clearFilters`.
//
// Los swatches de color no usan tokens M3 a propósito: representan el tono
// real de la pintura (rojo, azul...), ajeno al tema. Excepción intencionada
// y única, igual que el scrim monocromo sobre foto del carrusel.
pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var host

    // Claves de tono: deben coincidir con WallpaperColorService.tones y con
    // las que emite scripts/wallpaper-scan.py.
    readonly property var tonePaint: ({
                                          "red": "#e53935",
                                          "orange": "#fb8c00",
                                          "yellow": "#fdd835",
                                          "green": "#43a047",
                                          "cyan": "#00acc1",
                                          "blue": "#1e88e5",
                                          "purple": "#8e24aa",
                                          "pink": "#ec407a",
                                          "brown": "#8d6e63",
                                          "white": "#ffffff",
                                          "gray": "#9e9e9e",
                                          "black": "#212121"
                                      })

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

    function paintFor(tone: string): color {
        return root.tonePaint[tone] ?? Appearance.md3.surface_container_highest;
    }

    // ¿Hay resultados de este tono? Solo se atenúa cuando ya hay datos de
    // color (si no, todos los swatches parecerían vacíos antes del escaneo).
    function toneUnavailable(tone: string, active: bool): bool {
        const colorService = Services.WallpaperColorService;
        if (active || !colorService.ready || colorService.entries === 0)
            return false;
        return (colorService.counts[tone] ?? 0) === 0;
    }

    // Tinta (check) legible sobre un color de pintura arbitrario: negro o
    // blanco puros, ajenos al tema por la misma razón que los swatches.
    function inkFor(hex: string): color {
        const r = parseInt(hex.substr(1, 2), 16) / 255;
        const g = parseInt(hex.substr(3, 2), 16) / 255;
        const b = parseInt(hex.substr(5, 2), 16) / 255;
        const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        return luma > 0.55 ? Qt.rgba(0.1, 0.1, 0.1, 1.0) : Qt.rgba(1, 1, 1, 1);
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

    // ── Color dominante (multi-selección) ───────────────────────────────
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

        Repeater {
            model: Services.WallpaperColorService.tones

            delegate: Item {
                id: swatch

                required property string modelData

                readonly property bool active: root.host.toneFilter[modelData] === true
                readonly property color paint: root.paintFor(modelData)
                readonly property bool unavailable: root.toneUnavailable(modelData, active)

                implicitWidth: 30
                implicitHeight: 30

                Accessible.role: Accessible.CheckBox
                Accessible.name: root.label("wallpaper.color." + modelData, modelData)
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
                    opacity: swatch.unavailable ? Appearance.opacity.ghost : 1.0
                    scale: swatchMouse.containsMouse && !swatch.unavailable ? 1.12 : 1.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.motion.short3
                        }
                    }
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
                        color: root.inkFor(swatch.paint)
                        visible: swatch.active
                    }
                }

                MouseArea {
                    id: swatchMouse

                    anchors.fill: parent
                    enabled: !swatch.unavailable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.host.toggleTone(swatch.modelData)
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
