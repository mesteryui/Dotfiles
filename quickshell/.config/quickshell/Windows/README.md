# Windows

`SettingsPanel.qml` (light wrapper: `Scope` + IPC `ui.settings` +
`LazyLoader` window) and `SettingsPanelContent.qml` (sidebar + 4
tab pages: interface/appearance, screen/lock+light, environment/
weather+alerts, system/language+updates; labels via
`I18nService settings.tabs.*` / `settings.interface.*` keys).

Building blocks, one file each: `SettingsSectionCard`,
`SettingsFieldLabel`, `SettingsTextRow`, `SettingsSwitchRow`,
`SettingsDropdownRow`, `SettingsSidebarTab`.
