pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel // IMPORTANTE: Este es el módulo reactivo
import Quickshell
import Quickshell.Io
import qs.Core.Modules

import "../Log.js" as Log

Singleton {
    id: root

    property alias wallpaperList: folderModel
    property string wallpaperDir: Directories.pictures + "/Wallpapers"

    signal changed(newWallpaper: string)
    // Último error legible para la UI ("", extension, no existe, timeout...).
    property string error: ""
    property bool failed: false

    readonly property list<string> extensions: [
        "jpg", "jpeg", "png", "webp", "avif", "bmp", "svg"]

    FolderListModel {
        id: folderModel

        folder: Qt.resolvedUrl(root.wallpaperDir)
        nameFilters: root.extensions.map(e => `*.${e}`) // Filtra solo imágenes
        showDirs: false
        showDotAndDotDot: false
        sortReversed: false
        sortField: FolderListModel.Name
    }
    // Ruta pendiente de confirmar: solo se persiste y se emite `changed`
    // (→ matugen) cuando awww sale con 0. Sin esto, un fondo inexistente
    // o un awww fallido dejaba basura persistida + matugen sobre nada.
    // `notify=false` (restore) re-pone la imagen sin tocar matugen: los
    // colores ya existen del apply que eligió ese fondo.
    property string _pendingWallpaper: ""
    property bool _pendingNotify: true
    property var _queued: null

    Process {
        id: applyProcess

        onExited: code => {
            watchdog.stop();
            // Muerte provocada para superseder (cambio rápido de fondo):
            // retoma lo último pedido en vez de persistir lo viejo.
            if (root._queued !== null) {
                const q = root._queued;
                root._queued = null;
                root._apply(q.file, q.notify);
                return;
            }
            const done = root._pendingWallpaper;
            const notify = root._pendingNotify;
            root._pendingWallpaper = "";
            root._pendingNotify = true;
            if (done === "")
                return;
            if (code === 0) {
                root.failed = false;
                root.error = "";
                if (notify) {
                    Persistent.persistence.currentWallpaper = done;
                    root.changed(done);
                }
            } else {
                root.failed = true;
                root.error = code === 127 ? "awww no instalado" : "awww falló (" + code + ")";
                Log.warn("[Wallpaper] awww falló (" + code + "): " + done);
            }
        }
    }

    function apply(file: string): void {
        let fullPath = wallpaperDir + (wallpaperDir.endsWith("/") ? "" : "/") + file;
        root._apply(fullPath, true);
    }

    Timer {
        id: watchdog

        interval: 20000
        onTriggered: {
            if (applyProcess.running) {
                root.failed = true;
                root.error = "timeout aplicando fondo";
                Log.warn("[Wallpaper] timeout aplicando: " + root._pendingWallpaper);
                applyProcess.running = false;
            }
        }
    }

    function validImage(path: string): bool {
        if (!path)
            return false;
        const lower = String(path).toLowerCase();
        for (let i = 0; i < root.extensions.length; i++) {
            if (lower.endsWith("." + root.extensions[i]))
                return true;
        }
        return false;
    }

    function _apply(file: string, notify: bool) {
        if (file === "")
            return;
        if (!root.validImage(file)) {
            root.failed = true;
            root.error = "formato no soportado";
            Log.warn("[Wallpaper] formato no soportado: " + file);
            return;
        }
        if (applyProcess.running) {
            root._queued = { file: file, notify: notify };
            applyProcess.running = false;
            return;
        }
        root.failed = false;
        root.error = "";
        root._pendingWallpaper = file;
        root._pendingNotify = notify ?? true;
        applyProcess.command = ["awww", "img", file, "--transition-type", "center"];
        applyProcess.running = true;
        watchdog.restart();
    }

    // IPC: qs ipc call wallpaper set /ruta/absoluta/imagen.png
    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root._apply(path, true);
        }
        // Solo re-pone la imagen (p. ej. tras reiniciar el compositor):
        // nunca regenera colores.
        function restore(): void {
            root._apply(Persistent.persistence.currentWallpaper, false);
        }
    }
}
