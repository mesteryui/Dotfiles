pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel // IMPORTANTE: Este es el módulo reactivo
import Quickshell
import Quickshell.Io
import qs.Core.Modules

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
        // Imágenes + extensiones aportadas por proveedores
        // (capability wallpaper-backend; sin proveedor activo no hay rastro).
        nameFilters: root.extensions.concat(root.providerExtensions()).map(e => `*.${e}`)
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
    // `_pendingPersist=false` (frame de vídeo) notifica sin persistir:
    // currentWallpaper conserva el último estático para el restore.
    property string _pendingWallpaper: ""
    property bool _pendingNotify: true
    property bool _pendingPersist: true
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
                root._apply(q.file, q.notify, q.persist);
                return;
            }
            const done = root._pendingWallpaper;
            const notify = root._pendingNotify;
            const persist = root._pendingPersist;
            root._pendingWallpaper = "";
            root._pendingNotify = true;
            root._pendingPersist = true;
            if (done === "")
                return;
            if (code === 0) {
                root.failed = false;
                root.error = "";
                if (notify) {
                    if (persist)
                        Persistent.persistence.currentWallpaper = done;
                    root.changed(done);
                }
            } else {
                root.failed = true;
                root.error = code === 127 ? "awww no instalado" : "awww falló (" + code + ")";
                console.warn("[Wallpaper] awww falló (" + code + "): " + done);
                // Auto-reparación: si el daemon murió fuera de un escaneo
                // (crash, kill manual), se relanza al próximo uso.
                root.ensureBackend();
            }
        }
    }

    function apply(file: string): void {
        // Acepta nombre (relativo a wallpaperDir) o ruta absoluta (IPC).
        const fullPath = String(file || "").startsWith("/") ? String(file) : wallpaperDir + (wallpaperDir.endsWith("/") ? "" : "/") + file;
        // Proveedor externo (capability wallpaper-backend): el core no
        // sabe qué formato es, solo delega. Sin proveedor → camino normal
        // (falla con "formato no soportado", sin rastro).
        const provider = root.wallpaperProviderFor(fullPath);
        if (provider && typeof provider.applyWallpaper === "function") {
            try {
                root.failed = false;
                root.error = "";
                provider.applyWallpaper(fullPath);
            } catch (e) {
                root.failed = true;
                root.error = "el proveedor falló";
                console.warn("[Wallpaper] proveedor falló con: " + fullPath, e);
            }
            return;
        }
        root._apply(fullPath, true);
    }

    Timer {
        id: watchdog

        interval: 20000
        onTriggered: {
            if (applyProcess.running) {
                root.failed = true;
                root.error = "timeout aplicando fondo";
                console.warn("[Wallpaper] timeout aplicando: " + root._pendingWallpaper);
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

    // Póster de backend animado: aplica + notifica (matugen) SIN persistir.
    // currentWallpaper conserva el último estático para el restore.
    function applyPosterFrame(frame: string): void {
        root._apply(frame, true, false);
    }

    // --- Proveedores externos (capability wallpaper-backend) ---
    // El core no conoce formatos: agrega las extensiones anunciadas en
    // manifiestos, enruta apply() y miniaturas. Sin proveedor activo no
    // hay rastro (filtros, apply y thumbs caen al camino estático).
    property int thumbsRevision: 0

    function bumpThumbs() {
        root.thumbsRevision += 1;
    }

    function wallpaperProviders() {
        PluginService.revision;
        const out = [];
        const avail = PluginService.available;
        for (let i = 0; i < avail.length; i++) {
            const a = avail[i];
            if (a.type !== "daemon" || !PluginService.isEnabled(a.id))
                continue;
            if (PluginService.pluginErrors[a.id])
                continue;
            if ((a.capabilities || []).indexOf("wallpaper-backend") < 0)
                continue;
            out.push(a);
        }
        return out;
    }

    function providerExtensions() {
        const exts = [];
        const provs = root.wallpaperProviders();
        for (let i = 0; i < provs.length; i++) {
            const list = provs[i].extensions || [];
            for (let j = 0; j < list.length; j++) {
                const e = String(list[j]).toLowerCase();
                if (exts.indexOf(e) < 0)
                    exts.push(e);
            }
        }
        return exts;
    }

    function wallpaperProviderFor(path) {
        const lower = String(path || "").toLowerCase();
        const provs = root.wallpaperProviders();
        for (let i = 0; i < provs.length; i++) {
            const list = provs[i].extensions || [];
            for (let j = 0; j < list.length; j++)
                if (lower.endsWith("." + String(list[j]).toLowerCase()))
                    return PluginService.daemonObjectById(provs[i].id);
        }
        return null;
    }

    function isProviderWallpaper(path) {
        const lower = String(path || "").toLowerCase();
        const exts = root.providerExtensions();
        for (let i = 0; i < exts.length; i++)
            if (lower.endsWith("." + exts[i]))
                return true;
        return false;
    }

    function providerThumbnail(path) {
        const p = root.wallpaperProviderFor(path);
        if (!p || typeof p.cachedThumbnail !== "function")
            return "";
        try {
            return p.cachedThumbnail(path) || "";
        } catch (e) {
            return "";
        }
    }

    function requestProviderThumbnail(path) {
        const p = root.wallpaperProviderFor(path);
        if (!p || typeof p.requestThumbnail !== "function")
            return;
        try {
            p.requestThumbnail(path);
        } catch (e) {
        }
    }

    // Backend estático: la shell (no el compositor) es dueña de awww.
    // - Con proveedor activo (sonando) → no se toca awww.
    // - Si no → awww-daemon vivo + restore del estático (idempotente:
    //   si el daemon vive se asume bien y no se hace nada).
    // Se llama tras cada escaneo de plugins (cubre activar/desactivar).
    function ensureBackend() {
        if (ensureProc.running)
            return;
        const p = PluginService.providerForCapability("wallpaper-backend");
        if (p && p.active)
            return;
        ensureProc.running = true;
    }

    Process {
        id: ensureProc

        command: ["sh", "-c", "pgrep -x awww-daemon >/dev/null && echo ALIVE || echo DEAD"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "ALIVE")
                    root.ensureAlive = true;
            }
        }
        onRunningChanged: {
            if (running)
                root.ensureAlive = false;
        }
        onExited: code => {
            if (root.ensureAlive)
                return;
            launchProc.running = true;
        }
    }

    property bool ensureAlive: false

    Process {
        id: launchProc

        command: ["sh", "-c", "awww-daemon >/dev/null 2>&1 & sleep 1"]
        onExited: code => {
            root.restore();
        }
    }

    function _apply(file: string, notify: bool, persist: bool) {
        if (file === "")
            return;
        if (!root.validImage(file)) {
            root.failed = true;
            root.error = "formato no soportado";
            console.warn("[Wallpaper] formato no soportado: " + file);
            return;
        }
        if (applyProcess.running) {
            root._queued = { file: file, notify: notify, persist: persist };
            applyProcess.running = false;
            return;
        }
        root.failed = false;
        root.error = "";
        root._pendingWallpaper = file;
        root._pendingNotify = notify ?? true;
        root._pendingPersist = persist === undefined ? true : !!persist;
        applyProcess.command = ["awww", "img", file, "--transition-type", "center"];
        applyProcess.running = true;
        watchdog.restart();
    }

    // Solo re-pone la imagen (p. ej. tras reiniciar el compositor):
    // nunca regenera colores.
    function restore(): void {
        root._apply(Persistent.persistence.currentWallpaper, false);
    }

    // IPC: qs ipc call wallpaper set /ruta/absoluta
    // (cualquier formato: enruta igual que apply()).
    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root.apply(path);
        }
        function restore(): void {
            root.restore();
        }
    }
}
