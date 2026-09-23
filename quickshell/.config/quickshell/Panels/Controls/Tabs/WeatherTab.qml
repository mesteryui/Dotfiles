// WeatherTab — Pestaña de clima detallado estilo Material 3 Expressive.
// Tarjeta "hoy" con resumen + detalles a golpe de vista, y previsión por
// horas para el día actual y los tres siguientes (hourlyByDay).
pragma ComponentBehavior: Bound
import qs.Primitives
import qs.Core.Services as Services
import qs.Panels.Weather
import qs.Core
import qs.Core.Modules
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight

    function withAlpha(hex, a) {
        const c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function aqiLabel(level) {
        if (level >= 6)
            return Services.I18nService.getTranslation("weather.aqi_extremely_poor", "Pésima");
        if (level === 5)
            return Services.I18nService.getTranslation("weather.aqi_very_poor", "Muy mala");
        if (level === 4)
            return Services.I18nService.getTranslation("weather.aqi_poor", "Mala");
        if (level === 3)
            return Services.I18nService.getTranslation("weather.aqi_moderate", "Moderada");
        if (level === 2)
            return Services.I18nService.getTranslation("weather.aqi_fair", "Aceptable");
        if (level === 1)
            return Services.I18nService.getTranslation("weather.aqi_good", "Buena");
        return "--";
    }

    ColumnLayout {
        id: mainColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 8

        // ══ HOY: resumen + detalles en una sola tarjeta ═══════════
        M3Card {
            Layout.fillWidth: true
            padding: 12
            radius: 20
            color: Appearance.md3.surface_container_high

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: Icons.getWeatherIcon(Services.WeatherService.data.wCode, Services.WeatherService.data.isDay)
                            font.pixelSize: 42
                            color: Appearance.md3.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8
                            StyledText {
                                text: Services.WeatherService.data.temp
                                color: Appearance.md3.on_surface
                                font.pixelSize: 24
                                font.weight: Font.Medium
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.feels_like", "Sensación %1").arg(Services.WeatherService.data.tempFeelsLike)
                                color: Appearance.md3.on_surface_variant
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        StyledText {
                            text: Services.WeatherService.data.city
                            color: Appearance.md3.on_surface
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: Services.I18nService.getTranslation("weather.max_min", "Máx %1 · Mín %2").arg(Services.WeatherService.data.tempMax).arg(Services.WeatherService.data.tempMin)
                            color: Appearance.md3.on_surface_variant
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.withAlpha(Appearance.md3.outline_variant, 0.4)
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 10
                    columnSpacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "air"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.wind + " " + Services.WeatherService.data.windDir
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.wind", "Viento")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "water_drop"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.humidity
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.humidity", "Humedad")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "compress"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.press
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.pressure", "Presión")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "visibility"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.visib
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.visibility", "Visibilidad")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "rainy"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.precip + " · " + Services.WeatherService.data.precipProb
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.precipitation", "Precipitación")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "light_mode"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: String(Services.WeatherService.data.uv)
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.uv_index", "Índice UV")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "wb_twilight"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.sunrise
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.sunrise", "Amanecer")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "bedtime"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.sunset
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.sunset", "Atardecer")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "eco"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.aqi >= 0 ? Services.WeatherService.data.aqi + " · " + root.aqiLabel(Services.WeatherService.data.aqiLevel) : "--"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.aqi_title", "Calidad del aire")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            icon: "schedule"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.primary
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            StyledText {
                                text: Services.WeatherService.data.lastRefresh
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }
                            StyledText {
                                text: Services.I18nService.getTranslation("weather.updated", "Actualizado")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }
                }
            }
        }

        // ── Avisos MeteoAlarm (solo si los hay) ──
        WeatherAlerts {
            Layout.fillWidth: true
        }

        // ══ POR HORAS: HOY + 3 DÍAS ══════════════════════════════
        StyledText {
            visible: dayRepeater.count > 0
            text: Services.I18nService.getTranslation("weather.hourly", "Previsión por horas")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.md3.on_surface_variant
            Layout.fillWidth: true
        }

        Repeater {
            id: dayRepeater
            model: Services.WeatherService.data.hourlyByDay

            delegate: M3Card {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                padding: 12
                radius: 20
                color: Appearance.md3.surface_container_high

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialIcon {
                            icon: Icons.getWeatherIcon(modelData.wCode)
                            size: Appearance.font.pixelSize.large
                            color: Appearance.md3.primary
                        }

                        StyledText {
                            text: modelData.dayLabel
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface
                        }

                        StyledText {
                            text: modelData.shortDate
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.md3.on_surface_variant
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Máx / Mín del día, explícitos a golpe de vista
                        RowLayout {
                            spacing: 3

                            MaterialIcon {
                                icon: "arrow_upward"
                                size: 14
                                color: Appearance.md3.tertiary
                            }
                            StyledText {
                                text: modelData.maxTemp + "°"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }

                            MaterialIcon {
                                icon: "arrow_downward"
                                size: 14
                                color: Appearance.md3.primary
                            }
                            StyledText {
                                text: modelData.minTemp + "°"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                            }
                        }

                        StyledText {
                            visible: modelData.precipProb > 0
                            text: "☂ " + modelData.precipProb + "%"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.md3.tertiary
                        }
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        clip: true
                        contentWidth: hourRow.implicitWidth
                        contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: hourRow
                            spacing: 6
                            height: parent.height

                            Repeater {
                                model: modelData.hours

                                delegate: Rectangle {
                                    required property var modelData
                                    width: 54
                                    height: 92
                                    radius: 14
                                    color: root.withAlpha(Appearance.md3.surface_container_highest, 0.7)
                                    border.width: 0

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        width: parent.width

                                        StyledText {
                                            text: modelData.hourLabel
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: Appearance.md3.on_surface_variant
                                            horizontalAlignment: Text.AlignHCenter
                                            width: parent.width
                                        }

                                        MaterialIcon {
                                            icon: Icons.getWeatherIcon(modelData.wCode, modelData.isDay)
                                            size: 20
                                            color: Appearance.md3.primary
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        StyledText {
                                            text: modelData.temp + "°"
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: Font.Bold
                                            color: Appearance.md3.on_surface
                                            horizontalAlignment: Text.AlignHCenter
                                            width: parent.width
                                        }

                                        StyledText {
                                            text: modelData.precipProb > 0 ? modelData.precipProb + "%" : "—"
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: modelData.precipProb > 20 ? Appearance.md3.tertiary : Appearance.md3.on_surface_variant
                                            horizontalAlignment: Text.AlignHCenter
                                            width: parent.width
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Estado vacío / error
        M3Card {
            visible: Services.WeatherService.data.hourlyByDay.length === 0
            Layout.fillWidth: true
            padding: 12
            radius: 20
            color: root.withAlpha(Appearance.md3.surface_container_high, 0.7)

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                text: Services.WeatherService.isError ? Services.WeatherService.errorMessage : Services.I18nService.getTranslation("weather.loading", "Cargando previsión…")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.md3.on_surface_variant
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
}
