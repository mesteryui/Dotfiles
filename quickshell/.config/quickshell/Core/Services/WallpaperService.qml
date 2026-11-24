pragma Singleton

import qs.Core.Modules
import QtQuick
import Qt.labs.folderlistmodel // IMPORTANTE: Este es el módulo reactivo
import Quickshell
import Quickshell.Io // IpcHandler

// Fondos estáticos + animados (vídeo, opcional): el servicio valida,
// persiste y notifica.
// Sin proveedores externos (sin delegación, sin miniaturas ajenas, sin
// hooks de pausa): cualquier formato no listado en `extensions` o
// `videoExtensions` falla con "formato no soportado".
// Los vídeos solo existen si VideoSupport.available (QtMultimedia): sin él
// ni se listan ni se pueden aplicar.
Singleton {
    id: root

    property alias wallpaperList: folderModel
    property string wallpaperDir: Directories.pictures + "/Wallpapers"

    signal changed(newWallpaper: string)
    // Último error legible para la UI ("", extension, no existe, timeout...).

    property string error: ""

    property bool failed: false

    readonly property list<string> extensions: ["jpg", "jpeg", "png", "webp", "avif", "bmp", "svg"]

    readonly property list<string> videoExtensions: ["mp4", "webm", "mov", "mkv", "ogv", "m4v"]

    // Sin soporte de vídeo, los vídeos no aparecen como opción: evita que el
    // usuario elija algo que no se puede reproducir.
    function toFilters(exts) {
        return exts.map(e => "*." + e);
    }

    readonly property list<string> activeFilters: VideoSupport.available ? root.toFilters(
                                                                               root.extensions.concat(
                                                                                   root.videoExtensions)) :
                                                                           root.toFilters(root.extensions)

    FolderListModel {
        id: folderModel

        folder: Qt.resolvedUrl(root.wallpaperDir)
        nameFilters: root.activeFilters
        showDirs: false
        showDotAndDotDot: false
        sortReversed: false
        sortField: FolderListModel.Name
    }

    // Ruta confirmada al instante: validar, persistir y notificar es
    // síncrono.
    function apply(file: string): void {
        const raw = String(file || "").trim();
        if (raw === "" || /[\r\n\0]/.test(raw)) {
            root.failed = true;
            root.error = "ruta no válida";
            return;
        }

        // Acepta nombre (relativo a wallpaperDir) o ruta absoluta (IPC/drag).
        const baseDir = wallpaperDir + (wallpaperDir.endsWith("/") ? "" : "/");
        let fullPath = raw.startsWith("/") ? raw : baseDir + raw;

        // Normaliza separadores y rechaza traversal por segmento.
        fullPath = fullPath.replace(/\/+/g, "/");
        const segments = fullPath.split("/");
        if (segments.indexOf("..") >= 0) {
            root.failed = true;
            root.error = "ruta no válida";
            console.warn("[Wallpaper] ruta rechazada: " + raw);
            return;
        }

        // Para rutas relativas, exige basename simple (sin subdirectorios).
        if (!raw.startsWith("/")) {
            const base = raw.replace(/\\/g, "/");
            if (base.indexOf("/") >= 0) {
                root.failed = true;
                root.error = "ruta no válida";
                console.warn("[Wallpaper] ruta relativa no válida: " + raw);
                return;
            }
        } else {
            // Confinamiento básico para rutas absolutas: evita procesar archivos
            // arbitrarios del sistema fuera de ubicaciones típicas de usuario.
            const home = String(Quickshell.env("HOME") || "");
            const allowed = [wallpaperDir, home, "/usr/share/backgrounds", "/usr/share/wallpapers",
                             "/usr/share/pixmaps", "/usr/local/share/backgrounds",
                             "/usr/local/share/wallpapers", "/media", "/run/media", "/mnt"].filter(p => String(
                                                                                                            p || "").length
                                                                                                        > 0);
            let okRoot = false;
            for (let i = 0; i < allowed.length; i++) {
                const r = String(allowed[i]).replace(/\/+$/, "");
                if (r !== "" && (fullPath === r || fullPath.indexOf(r + "/") === 0)) {
                    okRoot = true;
                    break;
                }
            }
            if (!okRoot) {
                root.failed = true;
                root.error = "ruta fuera de ubicaciones permitidas";
                console.warn("[Wallpaper] ruta fuera de raíces permitidas: " + raw);
                return;
            }
        }

        if (root.isVideo(fullPath))
            root.applyVideo(fullPath, true);
        else
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

    function isVideo(path: string): bool {
        if (!path)
            return false;
        const lower = String(path).toLowerCase();
        for (let i = 0; i < root.videoExtensions.length; i++) {
            if (lower.endsWith("." + root.videoExtensions[i]))
                return true;
        }
        return false;
    }

    function validVideo(path: string): bool {
        return root.isVideo(path);
    }

    function validAny(path: string): bool {
        return root.validImage(path) || root.validVideo(path);
    }

    // Frame estatico derivado de un video (poster/fallback, lockscreen,
    // matugen). Para imagenes devuelve la misma ruta.
    function staticSourceFor(path: string): string {
        return root.isVideo(path) ? VideoFrameService.frameFor(path) : String(path || "");
    }

    // Video: persiste la ruta ORIGINAL (el frame se deriva siempre de ella)
    // y pide su frame estatico. Idempotente en disco: si el frame ya esta
    // vigente no se reescribe.
    function applyVideo(file: string, notify: bool): void {
        if (file === "")
            return;
        if (!root.validVideo(file)) {
            root.failed = true;
            root.error = "formato no soportado";
            console.warn("[Wallpaper] formato no soportado: " + file);
            return;
        }
        // Sonda lazy: una intención explícita de vídeo sí carga QtMultimedia.
        // Si la sonda aún vuela (!settled) se procede optimista (póster +
        // fallback del Loader); solo se falla cuando está confirmado que no
        // hay soporte. Sin esto, el primer applyVideo tras el arranque
        // fallaría siempre porque `available` aún es false.
        VideoSupport.ensureProbed();
        if (VideoSupport.settled && !VideoSupport.available) {
            root.failed = true;
            root.error = "video no soportado: falta QtMultimedia";
            console.warn("[Wallpaper] video sin soporte QtMultimedia: " + file);
            return;
        }
        root.failed = false;
        root.error = "";
        // Intencion explicita: revalida en disco (sin reescritura si el
        // frame sigue vigente).
        VideoFrameService.ensureFrame(file, true);
        if (notify ?? true) {
            Persistent.persistence.currentWallpaper = file;
            root.changed(file);
        }
    }

    // Solo re-pone el fondo (p. ej. tras reiniciar el compositor):
    // nunca regenera colores. Vale para imagen y video (el frame del video
    // se deriva de la ruta persistida).
    function restoreStatic(): void {
        const persisted = Persistent.persistence.currentWallpaper;
        if (root.isVideo(persisted))
            root.applyVideo(persisted, false);
        else
            root.applyStatic(persisted, false);
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
