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

    // Selección pendiente de asentar (ver schedule()).
    property int pendingIndex: -1
    property var pendingItem

    function reset() {
        debounce.stop();
        root.pendingIndex = -1;
        root.pendingItem = null;
        root.previewOk = false;
        root.previewCid = "";
        root.previewPath = "";
        root.previewFile = "";
        root.previewText = "";
        root.clipTextCid = "";
        root.clipText = "";
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
        root.pendingIndex = root.currentIndex;
        root.pendingItem = item;
        debounce.restart();
    }

    function update(item) {
        if (!MenuModes.supportsPreview(root.activeMode) || !MenuModes.needsPreview(root.activeMode, item)) {
            root.previewOk = false;
            root.previewCid = "";
            root.previewPath = "";
            root.previewFile = "";
            root.previewText = "";
            root.clipTextCid = "";
            root.clipText = "";
            return;
        }
        // Ya visible para este mismo item: no recargar (evita parpadeo).
        if (item && root.previewOk) {
            if ((item.kind === "clip" && item.isImage && item.cid === root.previewCid)
                || (item.kind === "file" && (item.media === "audio" || item.media === "video" || item.media === "pdf") && item.path === root.previewFile))
                return;
        }
        if (item && item.kind === "file" && item.media === "text" && item.path === root.previewFile && root.previewText !== "")
            return;
        root.previewOk = false;
        root.previewCid = "";
        root.previewPath = "";
        root.previewFile = "";
        root.previewText = "";
        root.clipTextCid = "";
        root.clipText = "";
        if (!item)
            return;
        if (item.kind === "clip" && item.isImage) {
            root.previewCid = item.cid;
            root.previewPath = Services.ClipboardService.previewImage(item.cid);
        } else if (ItemKinds.isClipText(item)) {
            // Texto completo vía decode (con fallback a la línea del listado
            // mientras llega). Sin previewOk: el cuerpo se muestra en cuanto
            // hay algo que enseñar.
            root.clipTextCid = item.cid;
            root.clipText = Services.ClipboardService.requestText(item.cid);
        } else if (item.kind === "file" && (item.media === "audio" || item.media === "video" || item.media === "pdf")) {
            root.previewFile = item.path;
            FilePreviewService.request(item.path, item.media);
        } else if (item.kind === "file" && item.media === "text") {
            root.previewFile = item.path;
            FilePreviewService.requestText(item.path);
        }
    }

    property Connections clipboardConn: Connections {
        target: Services.ClipboardService
        function onPreviewReady(cid) {
            if (cid === root.previewCid)
                root.previewOk = true;
        }
        function onTextReady(cid) {
            if (cid === root.clipTextCid)
                root.clipText = Services.ClipboardService.textContent;
        }
    }

    property Connections filePreviewConn: Connections {
        target: FilePreviewService
        function onReady(path, image) {
            if (path === root.previewFile && image !== "") {
                root.previewPath = image;
                root.previewOk = true;
            }
        }
        function onTextReady(path, text) {
            if (path === root.previewFile)
                root.previewText = text;
        }
    }

    property Timer debounce: Timer {
        interval: 120
        onTriggered: {
            // Solo si la selección sigue donde estaba al programar: si se
            // movió, ya hay otra llamada en camino y esta queda obsoleta.
            // Se lee el item fresco (el objeto puede haberse reconstruido).
            if (root.pendingIndex === root.currentIndex)
                root.update(root.currentItem);
            root.pendingIndex = -1;
            root.pendingItem = null;
        }
    }
}
