// Plugin de ejemplo (ver PLUGINS.md): sección bajo `>` (Sistema).
// Menú DINÁMICO: entries se regenera en refresh() (patrón FastfetchMenu).
// Los textos salen de i18n/<idioma>.json vía PluginService.tr().

import qs.Launcher
import qs.Core.Services as Services
import QtQuick
import Quickshell.Io

MenuDefinition {
    id: root

    sectionId: "example-hello"
    titleFallback: "Ejemplo Hola"
    titleKey: "plugin.example-hello.title"
    iconName: "extension"
    parentId: "main"

    entries: []

    function t(key, fallback) {
        return Services.PluginService.tr("example-hello", key, fallback);
    }

    function refresh() {
        if (!dateProc.running)
            dateProc.running = true;
    }

    property list<QtObject> helpers: [
        Process {
            id: dateProc

            command: ["date", "+%H:%M:%S"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const now = text.trim();
                    root.entries = [
                        root.shell("hola", root.t("hello", "Hola mundo"), root.t("hello_sub", "entrada de ejemplo"), "waving_hand", "notify-send 'shinro' 'El pipeline de plugins funciona'"),
                        root.shell("hora", root.t("time", "Qué hora es"), now, "schedule", "notify-send 'shinro' 'Son las " + now + "'"),
                        root.ipc("recargar", root.t("rescan", "Reescanear plugins"), "qs ipc call plugins rescan", "refresh", "plugins rescan"),
                        root.submenu("volver", root.t("back", "Volver"), "al menú Sistema", "arrow_back", "main")
                    ];
                }
            }
        }
    ]
}
