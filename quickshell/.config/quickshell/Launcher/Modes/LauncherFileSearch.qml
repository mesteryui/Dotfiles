// --- LauncherFileSearch: búsqueda de archivos del launcher con fd ---
// Lógica de mapeo/orden en FileMenu.js; aquí solo debounce + streaming
// al snapshot ordenado. AppLauncher aporta query/active y lee snapshot
// (+ failed) para pintar.
// (Extraído de AppLauncher.qml para partir sus ~1400 líneas.)
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "FileMenu.js" as FileMenu

QtObject {
    id: root

    property string query: ""
    property bool active: false

    // Snapshot [{path, name, isDir}] ordenado y estable (ver onExited).
    property var snapshot: []
    // true si el último escaneo fd falló (p. ej. fd no instalado):
    // el estado vacío lo explica en vez de mostrar "Sin resultados".
    property bool failed: false

    property ListModel buffer: ListModel {}

    function refresh() {
        fileProc.command = FileMenu.fdCommand(Quickshell.env("HOME"), root.query);
        fileProc.running = true;
    }

    onQueryChanged: {
        if (root.active)
            debounce.restart();
    }
    onActiveChanged: {
        if (root.active)
            debounce.restart();
    }

    property Timer debounce: Timer {
        interval: 250
        onTriggered: {
            if (!root.active)
                return;
            root.refresh();
        }
    }

    property Process fileProc: Process {
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "" || root.buffer.count >= 200)
                    return;
                const isDir = line.endsWith("/");
                // Las carpetas vienen con "/" final: se quita para el
                // nombre (si no, split("/").pop() daría "").
                const clean = isDir ? line.slice(0, -1) : line;
                const name = clean.split("/").pop();
                root.buffer.append({ path: line, name: name, isDir: isDir });
            }
        }
        onRunningChanged: {
            if (running) {
                root.buffer.clear();
                root.failed = false;
            }
        }
        onExited: code => {
            root.failed = code !== 0;
            const out = [];
            for (let i = 0; i < root.buffer.count; i++) {
                const e = root.buffer.get(i);
                out.push({ path: e.path, name: e.name, isDir: e.isDir });
            }
            // Ordenado y estable (ver FileMenu.sortSnapshot).
            FileMenu.sortSnapshot(out);
            root.snapshot = out;
        }
    }
}
