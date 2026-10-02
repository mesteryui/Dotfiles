pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel // IMPORTANTE: Este es el módulo reactivo
import Quickshell
import Quickshell.Io // IpcHandler
import qs.Core.Modules

// Solo wallpapers estáticos: el servicio valida, persiste y notifica.
// Sin proveedores externos (sin delegación, sin miniaturas ajenas, sin
// hooks de pausa): cualquier formato no listado en `extensions` falla
// con "formato no soportado".
Singleton {
    id: root

    property alias wallpaperList: folderModel
    property string wallpaperDir: Directories.pictures + "/Wallpapers"

    signal changed(newWallpaper: string)
    // Último error legible para la UI ("", extension, no existe, timeout...).
    property string error: ""
    property bool failed: false

    readonly property list<string> extensions: ["jpg", "jpeg", "png", "webp", "avif", "bmp", "svg"]

    FolderListModel {
        id: folderModel

        folder: Qt.resolvedUrl(root.wallpaperDir)
        nameFilters: root.extensions.map(e => `*.${e}`)
        showDirs: false
        showDotAndDotDot: false
        sortReversed: false
        sortField: FolderListModel.Name
    }

    // Ruta confirmada al instante: validar, persistir y notificar es
    // síncrono.
    function apply(file: string): void {
        // Acepta nombre (relativo a wallpaperDir) o ruta absoluta (IPC).
        const fullPath = String(file || "").startsWith("/") ? String(file) : wallpaperDir + (wallpaperDir.endsWith("/") ? "" : "/") + file;
        root.applyStatic(fullPath, true);
    }

    function applyStatic(file: string, notify: bool): void {
        if (file === "")
            return;
        if (!root.validImage(file)) {
            root.failed = true;
            root.error = "formato no soportado";
            console.warn("[Wallpaper] formato no soportado: " + file);
            return;
        }
        root.failed = false;
        root.error = "";
        if (notify ?? true) {
            Persistent.persistence.currentWallpaper = file;
            root.changed(file);
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

    // Solo re-pone la imagen (p. ej. tras reiniciar el compositor):
    // nunca regenera colores.
    function restoreStatic(): void {
        root.applyStatic(Persistent.persistence.currentWallpaper, false);
    }

    // IPC: qs ipc call wallpaper set /ruta/absoluta
    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root.apply(path);
        }
        function restore(): void {
            root.restoreStatic();
        }
    }
}
