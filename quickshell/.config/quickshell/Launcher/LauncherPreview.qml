// --- LauncherPreview: orquesta el preview lateral del launcher ---
// Estado + debounce + conexiones a ClipboardService/FilePreviewService.
// AppLauncher aporta activeMode/currentIndex/currentItem, llama a
// schedule() al resaltar y a reset() al abrir/cerrar; PreviewPanel lee
// el estado para pintar.
// Preview solo donde es imprescindible (ver MenuModes.js):
// clip siempre, files/system solo si el item trae imagen o texto.
// (Extraído de AppLauncher.qml para partir sus ~1400 líneas.)
pragma ComponentBehavior: Bound

import qs.Core.Services as Services
import "Base/MenuModes.js" as MenuModes
import "Base/ItemKinds.js" as ItemKinds
import QtQuick

QtObject {
    id: root

    property string activeMode: ""
    property int currentIndex: -1
    property var currentItem

    // ---------- preview de imagen del clipboard ----------
    property string previewCid: ""
    property bool previewOk: false
    property string previewPath: ""
    property string previewFile: ""
    property string previewText: ""
    // Texto completo del item de clipboard seleccionado (vía decode;
    // `cliphist list` solo trae la primera línea truncada).
    property string clipTextCid: ""
    property string clipText: ""
    // Previews de imagen que fallaron en esta sesión (decode imposible):
    // se muestra fallback y no se reintentan hasta reabrir.
    property var failedCids: []
    // Mensaje de error del preview actual ("": sin error).
    property string previewError: ""

    function previewFailedMessage() {
        return Services.I18nService.getTranslation("launcher.clip_preview_failed",
                                                   "No se pudo generar la vista previa de esta imagen");
    }

    // Selección pendiente de asentar (ver schedule()).
    property int pendingIndex: -1

    property var pendingItem

    // Vecinos del item actual (los pone AppLauncher desde
    // ResultList.neighborItems()): se prefetchAN sus previews para que el
    // siguiente highlight sea caché.
    property var neighbors: []

    // Metadatos del tema de audio actual (título/artista/álbum/duración).
    property string metaPath: ""

    property string metaText: ""

    function _fmtDur(secStr) {
        const secs = Math.round(parseFloat(secStr) || 0);
        if (secs <= 0)
            return "";
        return Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0");
    }

    function _composeMeta(title, artist, album, duration) {
        const line1 = artist !== "" && title !== "" ? artist + " — " + title : (title || artist || "");
        const dur = root._fmtDur(duration);
        const line2 = album !== "" && dur !== "" ? album + " · " + dur : (album || dur || "");
        if (line1 !== "" && line2 !== "")
            return line1 + "\n" + line2;
        return line1 || line2;
    }

    function reset() {
        debounce.stop();
        root.pendingIndex = -1;
        root.pendingItem = null;
        root.neighbors = [];
        root.previewOk = false;
        root.previewCid = "";
        root.previewPath = "";
        root.previewFile = "";
        root.previewText = "";
        root.clipTextCid = "";
        root.clipText = "";
        root.previewError = "";
        // Al reabrir se reintenta: el fallo pudo ser transitorio.
        root.failedCids = [];
        root.metaPath = "";
        root.metaText = "";
        Services.ClipboardService.clearPrefetch();
        FilePreviewService.clearPrefetch();
    }

    // Preview diferido: al moverse rápido por la lista (↑/↓, hover,
    // filtrado) solo se genera el del item donde se asienta la selección
    // (~120 ms). Lo barato (limpiar al caer en un item sin preview) es
    // inmediato para no retrasar el panel. Ver FilePreviewService
    // (además mata lo obsoleto).
    function schedule() {
        const item = root.currentItem;
        if (!MenuModes.supportsPreview(root.activeMode) || !MenuModes.needsPreview(root.activeMode, item)) {
            debounce.stop();
            root.pendingIndex = -1;
            root.pendingItem = null;
            update(item);
            return;
        }
        // Si cambió la clave del preview, limpiar estado viejo para no mostrarlo durante el debounce
        if (item) {
            const sameClip = root.previewCid !== "" && item.kind === "clip" && item.isImage && root.previewCid
                  === String(item.cid);
            const sameFile = root.previewFile !== "" && item.kind === "file" && (item.media === "audio"
                                                                                 || item.media === "video"
                                                                                 || item.media === "pdf"
                                                                                 || item.media === "text")
                  && root.previewFile === String(item.path || "");
            if (!sameClip && !sameFile && (root.previewOk || root.previewPath !== "" || root.previewText
                                           !== "" || root.previewError !== "")) {
                root.previewOk = false;
                root.previewPath = "";
                root.previewText = "";
                root.previewError = "";
            }
        }
        root.pendingIndex = root.currentIndex;
        root.pendingItem = item;
        debounce.restart();
    }

    // Prefetch de los vecinos del item actual (ver neighbors): el
    // siguiente highlight suele ser caché y se siente instantáneo. Solo
    // miniaturas pesadas (imágenes del clip, audio/video/pdf); el actual
    // siempre tiene prioridad en los servicios.
    function _prefetchNeighbors() {
        if (root.activeMode === "clip") {
            const cids = [];
            for (let i = 0; i < root.neighbors.length; i++) {
                const n = root.neighbors[i];
                if (n && n.kind === "clip" && n.isImage && n.cid !== root.previewCid && root.failedCids.indexOf(
                            n.cid) < 0)
                    cids.push(n.cid);
            }
            if (cids.length > 0)
                Services.ClipboardService.prefetchNeighbors(cids);
        } else if (root.activeMode === "files") {
            const pairs = [];
            for (let j = 0; j < root.neighbors.length; j++) {
                const f = root.neighbors[j];
                if (f && f.kind === "file" && (f.media === "audio" || f.media === "video" || f.media
                                               === "pdf") && f.path !== root.previewFile)
                    pairs.push([f.path, f.media]);
            }
            if (pairs.length > 0)
                FilePreviewService.prefetchNeighbors(pairs);
        }
    }

    function update(item) {
        // Prefetch de vecinos antes de nada: no depende del item actual y
        // deja las miniaturas en caché para el siguiente highlight.
        root._prefetchNeighbors();
        if (!MenuModes.supportsPreview(root.activeMode) || !MenuModes.needsPreview(root.activeMode, item)) {
            // Hueco transitorio (swap de modelo): NO limpiar lo que está en
            // vuelo (decode en curso). Si se limpiara, al completarse no
            // matchearía y el preview no se mostraría nunca sin re-navegar.
            // Al restaurarse la selección el update siguiente lo asienta.
            // Solo un item real sin preview limpia el estado.
            if (!item)
                return;
            root.previewOk = false;
            root.previewCid = "";
            root.previewPath = "";
            root.previewFile = "";
            root.previewText = "";
            root.clipTextCid = "";
            root.clipText = "";
            root.previewError = "";
            root.metaPath = "";
            root.metaText = "";
            return;
        }
        // Ya visible para este mismo item: no recargar (evita parpadeo).
        if (item && root.previewOk) {
            if ((item.kind === "clip" && item.isImage && item.cid === root.previewCid) || (item.kind
                                                                                           === "file" && (
                                                                                               item.media
                                                                                               === "audio"
                                                                                               || item.media
                                                                                               === "video"
                                                                                               || item.media
                                                                                               === "pdf")
                                                                                           && item.path
                                                                                           === root.previewFile))
                return;
        }
        // Para texto, no hacer early-return agresivo para permitir refresco si cambió el archivo
        // (si se quiere optimizar, se podría comparar mtime; por ahora siempre re-pedir es más correcto)
        if (false && item && item.kind === "file" && item.media === "text" && item.path === root.previewFile && root.previewText
                !== "")
            return;
        root.previewOk = false;
        root.previewCid = "";
        root.previewPath = "";
        root.previewFile = "";
        root.previewText = "";
        root.clipTextCid = "";
        root.clipText = "";
        root.previewError = "";
        if (!item)
            return;
        // Metadatos del tema actual (ffprobe, barato): el panel los pinta
        // bajo el título. Solo se pide al cambiar de tema; el servicio
        // cachea el último.
        if (item.kind === "file" && item.media === "audio") {
            if (item.path !== root.metaPath) {
                root.metaPath = item.path;
                root.metaText = "";
                FilePreviewService.requestMeta(item.path);
            }
        } else {
            root.metaPath = "";
            root.metaText = "";
        }
        if (item.kind === "clip" && item.isImage) {
            root.previewCid = item.cid;
            root.previewPath = Services.ClipboardService.previewImage(item.cid);
            root.previewOk = root.previewPath !== "";
            if (!root.previewOk) {
                root.previewError = ""; // no asumir fallo permanente; puede estar generándose
            } else {
                root.previewError = "";
            }
        } else if (ItemKinds.isClipText(item)) {
            // Texto completo vía decode (con fallback a la línea del listado
            // mientras llega). Sin previewOk: el cuerpo se muestra en cuanto
            // hay algo que enseñar.
            root.clipTextCid = item.cid;
            root.clipText = Services.ClipboardService.requestText(item.cid);
        } else if (item.kind === "file" && (item.media === "audio" || item.media === "video" || item.media
                                            === "pdf")) {
            root.previewFile = item.path;
            FilePreviewService.request(item.path, item.media);
        } else if (item.kind === "file" && item.media === "text") {
            root.previewFile = item.path;
            FilePreviewService.requestText(item.path);
        }
    }

    // El historial del backend puede cambiar mientras el panel está abierto
    // (evicción por límite, borrado, clear o reconexión). Si la miniatura del
    // clip seleccionado desaparece, hay que soltar la ruta antes de que
    // QQuickImage intente abrirla: si no, Qt registra "Cannot open" y deja el
    // hueco roto. El backend ya no publica rutas muertas; esto cubre la
    // ventana entre el cambio y la llegada del nuevo listado.
    function revalidateClipPreview() {
        if (root.previewCid === "")
            return;
        // Solo revalidar si sigue siendo el ítem clip-imagen actual
        if (!root.currentItem || root.currentItem.kind !== "clip" || !root.currentItem.isImage || String(
                    root.currentItem.cid) !== root.previewCid) {
            return;
        }
        const path = Services.ClipboardService.previewImage(root.previewCid);
        if (path === "") {
            root.previewOk = false;
            root.previewPath = "";
            // No marcar error transitorio: puede que aún se esté generando
            root.previewError = "";
            return;
        }
        if (path !== root.previewPath)
            root.previewPath = path;
        root.previewOk = true;
        root.previewError = "";
    }

    property Connections filePreviewConn: Connections {
        target: FilePreviewService

        function onReady(path, image) {
            if (path !== root.previewFile)
                return;
            if (image !== "") {
                root.previewPath = image;
                root.previewOk = true;
                root.previewError = "";
            } else {
                root.previewOk = false;
                root.previewPath = "";
                root.previewError = root.previewFailedMessage();
            }
        }

        function onTextReady(path, text) {
            if (path === root.previewFile)
                root.previewText = text;
        }

        function onMetaReady(path, title, artist, album, duration) {
            if (path === root.metaPath)
                root.metaText = root._composeMeta(title, artist, album, duration);
        }
    }

    // Cuando llega el contenido completo del portapapeles (get-text),
    // asignarlo a clipText si es para el item actualmente seleccionado.
    property Connections clipConn: Connections {
        target: Services.ClipboardService

        function onTextReady(cid) {
            if (cid === root.clipTextCid) {
                root.clipText = Services.ClipboardService.textContent || "";
            }
        }

        // El snapshot cambia con cada listado del backend: revalidar la
        // miniatura del clip seleccionado contra las entradas actuales.
        function onSnapshotChanged() {
            root.revalidateClipPreview();
        }
    }

    property Timer debounce: Timer {
        interval: 220
        onTriggered: {
            root.update(root.currentItem);
            root.pendingIndex = -1;
            root.pendingItem = null;
        }
    }
}
