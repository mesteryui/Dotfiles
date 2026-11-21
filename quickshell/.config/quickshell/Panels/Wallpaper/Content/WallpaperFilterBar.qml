// WallpaperFilterBar — fila de filtros estilo Komorebi / Ryoku
// Integrado con Matugen y el servicio de traducción i18n
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
            "labelKey": "wallpaper.filter.all",
            "fallback": "Todos"
        },
        {
            "key": "image",
            "labelKey": "wallpaper.filter.image",
            "fallback": "Imágenes"
        },
        {
            "key": "video",
            "labelKey": "wallpaper.filter.video",
            "fallback": "Vídeos"
        }
    ]

    function label(key: string, fallback: string): string {
        return Services.I18nService?.getTranslation(key, fallback) ?? fallback;
    }

    function colorLabel(): string {
        const colorService = Services.WallpaperColorService;
        if (colorService.scanning && colorService.entries === 0)
            return root.label("wallpaper.filter.analyzing", "Analizando colores…");
        return root.label("wallpaper.filter.color", "Color");
    }

    function colorName(id: int): string {
        const colorService = Services.WallpaperColorService;
        return root.label("wallpaper.color." + colorService.keys[id], colorService.names[id] ?? "");
    }

    spacing: 14

    // ── Tipo: Todos / Imágenes / Vídeos ─────────────────────────────────
    Row {
        Layout.alignment: Qt.AlignVCenter
        spacing: 12

        Repeater {
            model: root.typeModel

            delegate: Item {
                id: typePill

                required property var modelData

                readonly property bool active: root.host.typeFilter === modelData.key
                readonly property bool unavailable: modelData.key === "video"
                                                    && Services.VideoSupport.settled &&
                                                    !Services.VideoSupport.available

                implicitWidth: typeLabel.implicitWidth + 10
                implicitHeight: 32

                Accessible.role: Accessible.RadioButton
                Accessible.name: root.label(modelData.labelKey, modelData.fallback)
                Accessible.checked: active

                StyledText {
                    id: typeLabel

                    anchors.centerIn: parent
                    text: root.label(typePill.modelData.labelKey, typePill.modelData.fallback)
                    font.pixelSize: 12
                    font.weight: typePill.active ? Font.Bold : Font.Normal
                    color: typePill.active ? Appearance.md3.primary : Appearance.md3.on_surface_variant
                    opacity: typePill.unavailable ? Appearance.state.disabled : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.motion.fast
                        }
                    }
                }

                // Subrayado con el color primario de Matugen en la opción activa
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: typeLabel.implicitWidth
                    height: 2
                    radius: 1
                    color: Appearance.md3.primary
                    visible: typePill.active

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.motion.fast
                        }
                    }
                }

                MouseArea {
                    id: typeMouse

                    anchors.fill: parent
                    enabled: !typePill.unavailable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.host.typeFilter = typePill.modelData.key;
                        root.host.requestFocus();
                    }
                }
            }
        }
    }

    // Separador vertical
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        width: 1
        height: 16
        color: Qt.alpha(Appearance.md3.outline_variant, 0.40)
    }

    // ── "Color" + tira de colores cromáticos ────────────────────────────
    Row {
        Layout.alignment: Qt.AlignVCenter
        spacing: 8

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "palette"
                size: 15
                color: Appearance.md3.on_surface_variant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.colorLabel()
                font.pixelSize: 11
                color: Appearance.md3.on_surface_variant
            }

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "expand_more"
                size: 13
                color: Qt.alpha(Appearance.md3.on_surface_variant, 0.60)
            }
        }

        // Tira de swatches de color (colores calculados de los wallpapers)
        Row {
            id: swatchRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Repeater {
                model: Services.WallpaperColorService.presentGroups

                delegate: Item {
                    id: swatch

                    required property int modelData

                    readonly property bool active: root.host.colorFilter === modelData
                    readonly property color paint: Services.WallpaperColorService.swatch(modelData)

                    implicitWidth: 14
                    implicitHeight: 14

                    Accessible.role: Accessible.RadioButton
                    Accessible.name: root.colorName(modelData)
                    Accessible.checked: active

                    Rectangle {
                        anchors.centerIn: parent
                        width: swatch.active ? 13 : 9
                        height: width
                        radius: width / 2
                        color: swatch.paint
                        border.width: swatch.active ? 2 : 0
                        border.color: Appearance.md3.on_surface
                        scale: swatchMouse.containsMouse ? 1.3 : 1.0

                        Behavior on scale {
                            SpringAnimation {
                                spring: 3.5
                                damping: 0.22
                                mass: 0.6
                                epsilon: 0.005
                            }
                        }
                    }

                    MouseArea {
                        id: swatchMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.host.toggleColor(swatch.modelData);
                            root.host.requestFocus();
                        }
                    }
                }
            }
        }
    }

    // ── Botón Limpiar filtros (solo si hay alguno activo) ───────────────
    Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: root.host.filtersActive ? clearRow.implicitWidth + 14 : 0
        implicitHeight: 22
        visible: root.host.filtersActive
        clip: true

        Behavior on implicitWidth {
            SpringAnimation {
                spring: 3.0
                damping: 0.25
                mass: 0.7
                epsilon: 0.25
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.shape.full
            color: clearMouse.containsMouse ? Appearance.md3.surface_container_highest :
                                              Appearance.md3.surface_container
            border.color: Qt.alpha(Appearance.md3.outline, 0.25)
            border.width: 1

            Row {
                id: clearRow

                anchors.centerIn: parent
                spacing: 4

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "filter_alt_off"
                    size: 12
                    color: Appearance.md3.on_surface_variant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label("wallpaper.filter.clear", "Limpiar")
                    font.pixelSize: 10
                    color: Appearance.md3.on_surface_variant
                }
            }

            MouseArea {
                id: clearMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.host.clearFilters();
                    root.host.requestFocus();
                }
            }
        }
    }
}
