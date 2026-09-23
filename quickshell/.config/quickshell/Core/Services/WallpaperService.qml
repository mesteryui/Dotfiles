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

    readonly property list<string> extensions: [ // TODO: add videos
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
              if (notify) {
                 Persistent.persistence.currentWallpaper = done;
                 root.changed(done);
               }
            } else {
                Log.warn("[Wallpaper] awww falló (" + code + "): " + done);
            }
        }
    }

    function apply(file: string): void {
        let fullPath = wallpaperDir + (wallpaperDir.endsWith("/") ? "" : "/") + file;
        root._apply(fullPath, true);
    }

    function _apply(file: string, notify: bool) {
        if (file === "")
            return;
        if (applyProcess.running) {
            root._queued = { file: file, notify: notify };
            applyProcess.running = false;
            return;
        }
        root._pendingWallpaper = file;
        root._pendingNotify = notify ?? true;
        applyProcess.command = ["awww", "img", file, "--transition-type", "center"];
        applyProcess.running = true;
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
