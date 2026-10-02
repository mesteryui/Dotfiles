// --- SettingsPanelContent.qml ---
pragma ComponentBehavior: Bound
import qs.Core.Services as Services
import qs.Primitives
import qs.Core
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property int currentTab: 0

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
        anchors.margins: Appearance.spacing.l
        spacing: Appearance.spacing.l

        // 1. BARRA LATERAL IZQUIERDA (Ancho compacto y proporcionado)
        ColumnLayout {
            id: sidebar
            Layout.preferredWidth: 150
            Layout.maximumWidth: 150
            Layout.fillHeight: true

            spacing: 6

            StyledText {
                text: Services.I18nService.getTranslation("settings.title", "Ajustes")
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Medium
                font.variableAxes: Appearance.font.variableAxes.title
                color: Appearance.md3.on_surface
                Layout.bottomMargin: 8
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            SettingsSidebarTab {
                iconName: "palette"
                title: Services.I18nService.getTranslation("settings.tabs.interface.title", "Interfaz")
                description: Services.I18nService.getTranslation("settings.tabs.interface.description", "Apariencia")
                selected: root.currentTab === 0
                onClicked: root.currentTab = 0
            }
            SettingsSidebarTab {
                iconName: "display_settings"
                title: Services.I18nService.getTranslation("settings.tabs.screen.title", "Pantalla")
                description: Services.I18nService.getTranslation("settings.tabs.screen.description", "Bloqueo y luz")
                selected: root.currentTab === 1
                onClicked: root.currentTab = 1
            }
            SettingsSidebarTab {
                iconName: "partly_cloudy_day"
                title: Services.I18nService.getTranslation("settings.tabs.environment.title", "Entorno")
                description: Services.I18nService.getTranslation("settings.tabs.environment.description", "Clima y avisos")
                selected: root.currentTab === 2
                onClicked: root.currentTab = 2
            }
            SettingsSidebarTab {
                iconName: "settings"
                title: Services.I18nService.getTranslation("settings.tabs.system.title", "Sistema")
                description: Services.I18nService.getTranslation("settings.tabs.system.description", "Idioma y updates")
                selected: root.currentTab === 3
                onClicked: root.currentTab = 3
            }
            SettingsSidebarTab {
                iconName: "extension"
                title: Services.I18nService.getTranslation("settings.tabs.plugins.title", "Plugins")
                description: Services.I18nService.getTranslation("settings.tabs.plugins.description", "Extensiones")
                selected: root.currentTab === 4
                onClicked: root.currentTab = 4
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
                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.interface.appearance.title", "Apariencia")

                    SettingsSwitchRow {
                        label: Services.I18nService.getTranslation("settings.interface.appearance.dark_mode", "Modo oscuro")
                        stateText: Services.ConfigService.configs.appearance.darkMode ? Services.I18nService.getTranslation("settings.common.activated", "Activado") : Services.I18nService.getTranslation("settings.common.deactivated", "Desactivado")
                        iconName: "dark_mode"
                        checked: Services.ConfigService.configs.appearance.darkMode
                        onToggled: Services.ConfigService.configs.appearance.darkMode = !Services.ConfigService.configs.appearance.darkMode
                    }

                    SettingsSwitchRow {
                        label: Services.I18nService.getTranslation("settings.interface.appearance.reduce_motion", "Reducir movimiento")
                        stateText: Services.ConfigService.configs.appearance.reduceMotion ? Services.I18nService.getTranslation("settings.common.activated", "Activado") : Services.I18nService.getTranslation("settings.common.deactivated", "Desactivado")
                        iconName: "motion_photos_off"
                        checked: Services.ConfigService.configs.appearance.reduceMotion
                        onToggled: Services.ConfigService.configs.appearance.reduceMotion = !Services.ConfigService.configs.appearance.reduceMotion
                    }

                    SettingsDropdownRow {
                        label: Services.I18nService.getTranslation("settings.interface.appearance.color_scheme", "Esquema de color (matugen)")
                        iconName: "palette"
                        value: Services.ConfigService.configs.appearance.matugen.type
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
                        onChosen: val => Services.ConfigService.configs.appearance.matugen.type = val
                    }

                    SettingsTextRow {
                        label: Services.I18nService.getTranslation("settings.interface.appearance.font_sans", "Fuente principal (sans)")
                        value: Services.ConfigService.configs.appearance.fontSans
                        onEdited: text => Services.ConfigService.configs.appearance.fontSans = text
                    }
                    SettingsTextRow {
                        label: Services.I18nService.getTranslation("settings.interface.appearance.font_mono", "Fuente monoespaciada")
                        value: Services.ConfigService.configs.appearance.monospace
                        onEdited: text => Services.ConfigService.configs.appearance.monospace = text
                    }
                    SettingsTextRow {
                        label: Services.I18nService.getTranslation("settings.interface.appearance.font_reading", "Fuente de lectura")
                        value: Services.ConfigService.configs.appearance.reading
                        onEdited: text => Services.ConfigService.configs.appearance.reading = text
                    }
                    SettingsTextRow {
                        label: Services.I18nService.getTranslation("settings.interface.appearance.font_expressive", "Fuente expresiva")
                        value: Services.ConfigService.configs.appearance.expressive
                        onEdited: text => Services.ConfigService.configs.appearance.expressive = text
                    }
                }

                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.interface.bar.title", "Barra")

                    SettingsDropdownRow {
                        label: Services.I18nService.getTranslation("settings.interface.bar.position", "Posición")
                        iconName: "swap_vert"
                        value: Services.ConfigService.configs.bar.position
                        choicesModel: [
                            {
                                value: "top",
                                text: Services.I18nService.getTranslation("settings.interface.bar.position_top", "Arriba")
                            },
                            {
                                value: "bottom",
                                text: Services.I18nService.getTranslation("settings.interface.bar.position_bottom", "Abajo")
                            }
                        ]
                        onChosen: val => Services.ConfigService.configs.bar.position = val
                    }

                    ControlSlider {
                        Layout.fillWidth: true
                        label: Services.I18nService.getTranslation("settings.interface.bar.height", "Altura")
                        iconName: "height"
                        value: root.toSlider(Services.ConfigService.configs.bar.height, 24, 64)
                        valueText: Services.ConfigService.configs.bar.height + " px"
                        onMoved: val => Services.ConfigService.configs.bar.height = root.fromSlider(val, 24, 64)
                    }

                    SettingsDropdownRow {
                        label: Services.I18nService.getTranslation("settings.interface.bar.workspace_style", "Estilo de espacios de trabajo")
                        iconName: "tag"
                        value: Services.ConfigService.configs.bar.workspaceButtonType
                        choicesModel: [
                            {
                                value: "numbers",
                                text: Services.I18nService.getTranslation("settings.interface.bar.workspace_style_numbers", "Números")
                            },
                            {
                                value: "kanji",
                                text: Services.I18nService.getTranslation("settings.interface.bar.workspace_style_kanji", "Kanji")
                            },
                            {
                                value: "circles",
                                text: Services.I18nService.getTranslation("settings.interface.bar.workspace_style_circles", "Círculos")
                            }
                        ]
                        onChosen: val => Services.ConfigService.configs.bar.workspaceButtonType = val
                    }
                    SettingsDropdownRow {
                        label: Services.I18nService.getTranslation("settings.interface.bar.type", "Tipo de barra")
                        iconName: "web_asset"
                        value: Services.ConfigService.configs.bar.barType
                        choicesModel: [
                            {
                                value: "floating",
                                text: Services.I18nService.getTranslation("settings.interface.bar.type_floating", "Flotante")
                            },
                            {
                                value: "full_hug",
                                text: Services.I18nService.getTranslation("settings.interface.bar.type_full_hug", "Completa (Full hug)")
                            },
                            {
                                value: "partial_hug",
                                text: Services.I18nService.getTranslation("settings.interface.bar.type_partial_hug", "Parcial (Partial hug)")
                            },
                            {
                                value: "no_floating",
                                text: Services.I18nService.getTranslation("settings.interface.bar.type_no_floating", "No flotante")
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
                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.screen.lockscreen.title", "Pantalla de bloqueo")

                    SettingsSwitchRow {
                        label: Services.I18nService.getTranslation("settings.screen.lockscreen.use_wallpaper", "Usar fondo de pantalla")
                        stateText: Services.ConfigService.configs.lockscreen.useWallpaper ? Services.I18nService.getTranslation("settings.common.activated", "Activado") : Services.I18nService.getTranslation("settings.common.deactivated", "Desactivado")
                        iconName: "wallpaper"
                        checked: Services.ConfigService.configs.lockscreen.useWallpaper
                        onToggled: Services.ConfigService.configs.lockscreen.useWallpaper = !Services.ConfigService.configs.lockscreen.useWallpaper
                    }

                    ControlSlider {
                        Layout.fillWidth: true
                        label: Services.I18nService.getTranslation("settings.screen.lockscreen.blur_level", "Nivel de desenfoque")
                        iconName: "blur_on"
                        value: root.toSlider(Services.ConfigService.configs.lockscreen.blurLevel, 0.0, 3.0)
                        valueText: Services.ConfigService.configs.lockscreen.blurLevel.toFixed(1) + "x"
                        onMoved: val => Services.ConfigService.configs.lockscreen.blurLevel = root.fromSlider(val, 0.0, 3.0, 2)
                    }
                }

                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.screen.night_light.title", "Luz nocturna")

                    ControlSlider {
                        Layout.fillWidth: true
                        label: Services.I18nService.getTranslation("settings.screen.night_light.temperature", "Temperatura de color")
                        iconName: "thermostat"
                        value: root.toSlider(Services.ConfigService.configs.nightLight.temperature, 1000, 6500)
                        valueText: Services.ConfigService.configs.nightLight.temperature + " K"
                        onMoved: val => {
                            const k = root.fromSlider(val, 1000, 6500);
                            Services.ConfigService.configs.nightLight.temperature = k;
                            // Solo aplica en vivo si el filtro está encendido;
                            // apagado solo guarda preferencia (se aplica al activar).
                            if (!Services.Hyprsunset.identity)
                                Services.Hyprsunset.setTemperature(k);
                        }
                    }

                    ControlSlider {
                        Layout.fillWidth: true
                        label: Services.I18nService.getTranslation("settings.screen.night_light.gamma", "Gamma")
                        iconName: "exposure"
                        value: root.toSlider(Services.ConfigService.configs.nightLight.gamma, 0, 100)
                        valueText: Services.ConfigService.configs.nightLight.gamma + "%"
                        onMoved: val => {
                            const g = root.fromSlider(val, 0, 100);
                            Services.ConfigService.configs.nightLight.gamma = g;
                            // Igual que temperatura: apagado solo guarda.
                            if (!Services.Hyprsunset.identity)
                                Services.Hyprsunset.setGamma(g);
                        }
                    }
                }
                Item {
                    Layout.preferredHeight: 8
                }
            }

            // ── PESTAÑA 2: ENTORNO ──
            TabFlickable {
                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.environment.weather.title", "Clima")

                    SettingsSwitchRow {
                        label: Services.I18nService.getTranslation("settings.environment.weather.auto_location", "Ubicación automática")
                        stateText: Services.ConfigService.configs.weather.autoLocation ? Services.I18nService.getTranslation("settings.common.activated", "Activado") : Services.I18nService.getTranslation("settings.common.deactivated", "Desactivado")
                        iconName: "my_location"
                        checked: Services.ConfigService.configs.weather.autoLocation
                        onToggled: Services.ConfigService.configs.weather.autoLocation = !Services.ConfigService.configs.weather.autoLocation
                    }

                    SettingsTextRow {
                        label: Services.I18nService.getTranslation("settings.environment.weather.city", "Ciudad")
                        value: Services.ConfigService.configs.weather.city
                        onEdited: text => Services.ConfigService.configs.weather.city = text
                        enabled: !Services.ConfigService.configs.weather.autoLocation
                        opacity: enabled ? 1.0 : 0.45
                    }

                    ControlSlider {
                        Layout.fillWidth: true
                        label: Services.I18nService.getTranslation("settings.environment.weather.refresh_rate", "Frecuencia de actualización")
                        iconName: "refresh"
                        value: root.toSlider(Services.ConfigService.configs.weather.reloadTime, 1, 60)
                        valueText: Services.ConfigService.configs.weather.reloadTime + " min"
                        onMoved: val => Services.ConfigService.configs.weather.reloadTime = root.fromSlider(val, 1, 60)
                    }
                }

                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.environment.notifications.title", "Notificaciones")

                    ControlSlider {
                        Layout.fillWidth: true
                        label: Services.I18nService.getTranslation("settings.environment.notifications.timeout", "Tiempo de espera")
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
                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.system.language.title", "Idioma")

                    SettingsDropdownRow {
                        label: Services.I18nService.getTranslation("settings.system.language.selection", "Seleccion de idiomas")
                        iconName: "translate"
                        value: Services.ConfigService.configs.language
                        choicesModel: [
                            {
                                "value": "es_ES",
                                "text": Services.I18nService.getTranslation("settings.system.language.es", "Español de España")
                            },
                            {
                                "value": "en_US",
                                "text": Services.I18nService.getTranslation("settings.system.language.en", "Ingles de EEUU")
                            },
                            {
                                "value": "eo",
                                "text": Services.I18nService.getTranslation("settings.system.language.eo", "Esperanto")
                            },
                            {
                                "value": "auto",
                                "text": "Auto"
                            }
                        ]
                        onChosen: val => Services.ConfigService.configs.language = val
                    }
                }

                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.system.updates.title", "Actualizaciones")

                    ControlSlider {
                        Layout.fillWidth: true
                        label: Services.I18nService.getTranslation("settings.system.updates.check_frequency", "Frecuencia de comprobación")
                        iconName: "update"
                        value: root.toSlider(Services.ConfigService.configs.updates.countTime, 5, 180)
                        valueText: Services.ConfigService.configs.updates.countTime + " min"
                        onMoved: val => Services.ConfigService.configs.updates.countTime = root.fromSlider(val, 5, 180)
                    }

                    SettingsTextRow {
                        label: Services.I18nService.getTranslation("settings.system.updates.command", "Comando")
                        value: Services.ConfigService.configs.updates.command
                        onEdited: text => Services.ConfigService.configs.updates.command = text
                    }
                }
                Item {
                    Layout.preferredHeight: 8
                }
            }

            // ── PESTAÑA 4: PLUGINS ──
            TabFlickable {
                SettingsSectionCard {
                    title: Services.I18nService.getTranslation("settings.plugins.title", "Plugins")

                    Repeater {
                        model: Services.PluginService.available

                        delegate: SettingsSwitchRow {
                            required property var modelData

                            label: (modelData.name || modelData.id) + " " + (modelData.version || "")
                            stateText: Services.PluginService.statusOf(modelData)
                            iconName: "extension"
                            checked: Services.PluginService.isEnabled(modelData.id)
                            onToggled: Services.PluginService.setEnabled(modelData.id, !Services.PluginService.isEnabled(modelData.id))
                        }
                    }

                    StyledText {
                        visible: Services.PluginService.available.length === 0
                        text: Services.I18nService.getTranslation("settings.plugins.empty", "Sin plugins instalados")
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
