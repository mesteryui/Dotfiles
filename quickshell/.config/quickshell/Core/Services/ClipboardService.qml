// --- ClipboardService (Singleton) ---
// Historial del portapapeles vía cliphist
// (`cliphist list | decode | delete | wipe` + `wl-copy`).
// Borrado por id con `echo <id> | cliphist delete` (delete-query borra por
// contenido y no sirve para una entrada concreta).
// Soporta texto e imágenes: las entradas `[[ binary data ... ]]` se marcan
// como imagen y al previsualizar/copiar se decodifican a /tmp.
//
// Requiere el daemon (añadido a hypr auto-exec):
//   wl-paste --type text --watch cliphist store &
//   wl-paste --type image --watch cliphist store &

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import "../Log.js" as Log

Singleton {
    id: root

    // Al cambiar el idioma se reconstruye el snapshot (subs traducidos).
    readonly property string langWatch: I18nService.language

    onLangWatchChanged: rebuildSnapshot()

    property ListModel entries: ListModel {}
    // Snapshot plano para bindings: entries se llena por streaming y leerlo
    // en vivo desde `results` disparaba binding loops. Solo se reasigna al
    // completar el listado.
    property var snapshot: []
    property bool ready: false
    property string error: ""
    property bool refreshing: false

    readonly property string previewDir: "/tmp/qs-clipboard"

    property string copyId: ""
    property bool copyIsImage: false
    property string previewId: ""
    // Cola para no perder peticiones si se pulsa muy rápido:
    // solo gana la última (igual que FilePreviewService).
    property string pendingCopyId: ""
    property bool pendingCopyIsImage: false
    property bool hasPendingCopy: false
    property string pendingPreviewId: ""
    property var pendingDeleteQueue: []
    property bool pendingRefresh: false

    signal previewReady(string cid)
    // El decode falló (entrada expirada, binario corrupto...): sin esta
    // señal el preview se quedaría esperando eternamente en blanco y
    // reintentando el decode en cada highlight. El display muestra
    // fallback y no lo reintenta en la sesión.
    signal previewFailed(string cid)

    // Cola de prefetch (baja prioridad): cids vecinos al actual. Se
    // reemplaza en cada highlight y solo corre en idle: la petición real
    // (previewImage/pendingPreviewId) siempre pasa delante.
    property var prefetchQueue: []

    function prefetchNeighbors(cids) {
        const out = [];
        for (let i = 0; i < cids.length && out.length < 6; i++) {
            const id = String(cids[i]).trim();
            if (!isValidId(id) || id === root.previewId || id === root.pendingPreviewId)
                continue;
            if (out.indexOf(id) < 0)
                out.push(id);
        }
        root.prefetchQueue = out;
        root._pumpPreview();
    }

    function clearPrefetch() {
        root.prefetchQueue = [];
    }

    function _pumpPreview() {
        // OJO: el Process se referencia por su id directo (previewProc):
        // los id NO son propiedades (root.previewProc es undefined y
        // lanzaba TypeError, abortando update() antes de pedir nada).
        if (previewProc.running || root.pendingPreviewId !== "")
            return;
        if (root.prefetchQueue.length === 0)
            return;
        root.startPreview(root.prefetchQueue[0]);
        root.prefetchQueue = root.prefetchQueue.slice(1);
    }

    function shEscape(s) {
        // Copia local a propósito: Core no debe depender del módulo
        // qs.Launcher (ver Launcher/Base/ShellUtils.js, misma semántica).
        return String(s).replace(/'/g, "'\\''");
    }

    function isValidId(cid) {
        return /^[0-9]+$/.test(String(cid).trim());
    }

    function refresh() {
        // Si el listado está en curso, no lo abortamos: marcamos
        // pendiente y se refresca solo al terminar (evita lista vacía).
        if (listProc.running) {
            pendingRefresh = true;
            return;
        }
        entries.clear();
        // No vaciamos `snapshot` aquí: se reasigna al completar.
        // Así la lista no parpadea en vacío en cada Supr.
        error = "";
        refreshing = true;
        listProc.running = true;
    }

    function rebuildSnapshot() {
        const out = [];
        for (let i = 0; i < entries.count; i++) {
            const e = entries.get(i);
            out.push({ cid: e.cid, text: e.text, raw: e.raw, isImage: e.isImage });
        }
        snapshot = out;
    }

    function copyEntry(cid, isImage) {
        const id = String(cid).trim();
        if (!isValidId(id)) {
            Log.warn("ClipboardService: copy con id inválido '" + cid + "'");
            return;
        }
        // Si ya hay una copia en curso, encolamos solo la última.
        if (copyProc.running) {
            pendingCopyId = id;
            pendingCopyIsImage = !!isImage;
            hasPendingCopy = true;
            return;
        }
        startCopy(id, !!isImage);
    }

    function startCopy(id, isImage) {
        copyId = id;
        copyIsImage = isImage;
        // Asignación imperativa: evita la carrera de usar `command:`
        // ligado a la propiedad y `running = true` en la misma función
        // (el proceso podía arrancar con el id anterior).
        if (isImage)
            copyProc.command = ["sh", "-c", "cliphist decode '" + shEscape(id) + "' | wl-copy --type image/png"];
        else
            copyProc.command = ["sh", "-c", "cliphist decode '" + shEscape(id) + "' | wl-copy"];
        copyProc.running = true;
    }

    // Copia texto arbitrario al portapapeles (vía única para emoji y
    // calculadora del launcher). Desacoplado como el resto de
    // lanzamientos: no bloquea ni interfiere con copias en curso de
    // entradas del historial (esas siguen su propia cola en copyProc).
    // El texto viaja como argumento $1, NUNCA interpolado en el shell:
    // ni siquiera un portapapeles hostil puede escapar el quoting.
    function copyText(text) {
        const t = String(text ?? "");
        if (t === "")
            return false;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "wl-copy-text", t]);
        return true;
    }

    // Devuelve la ruta donde quedará el preview (emite previewReady al terminar)
    function previewImage(cid) {
        const id = String(cid).trim();
        if (!isValidId(id))
            return "";
        // Si hay preview en curso, solo gana el último (navegación rápida).
        if (previewProc.running) {
            pendingPreviewId = id;
            return previewDir + "/preview-" + id + ".png";
        }
        startPreview(id);
        return previewDir + "/preview-" + id + ".png";
    }

    function startPreview(id) {
        previewId = id;
        previewProc.command = ["sh", "-c", "mkdir -p '" + shEscape(previewDir) + "' && OUT='" + shEscape(previewDir) + "/preview-" + shEscape(id) + ".png' && ([ -s \"$OUT\" ] || cliphist decode '" + shEscape(id) + "' > \"$OUT\")"];
        previewProc.running = true;
    }

    // Texto completo de una entrada de texto (`cliphist list` solo trae la
    // primera línea truncada; para la preview hay que hacer `decode`).
    // Tope 20000 caracteres en el acumulador; si se corta, se marca con "…".
    property string textCid: ""
    property string textContent: ""
    property string textAcc: ""
    property string pendingTextId: ""
    signal textReady(string cid)

    // Pide el texto completo; devuelve el cacheado si ya es de este cid,
    // "" si queda pendiente (llega vía textReady). Solo gana el último
    // si se navega rápido (igual que previewImage).
    function requestText(cid) {
        const id = String(cid).trim();
        if (!isValidId(id))
            return "";
        if (id === textCid && textContent !== "")
            return textContent;
        if (textProc.running) {
            pendingTextId = id;
            return "";
        }
        startTextRequest(id);
        return "";
    }

    function startTextRequest(id) {
        textCid = id;
        textContent = "";
        textAcc = "";
        pendingTextId = "";
        textProc.command = ["sh", "-c", "cliphist decode '" + shEscape(id) + "' 2>/dev/null | head -c 20000"];
        textProc.running = true;
    }

    function deleteEntry(cid) {
        const id = String(cid).trim();
        if (!isValidId(id)) {
            Log.warn("ClipboardService: delete con id inválido '" + cid + "'");
            return;
        }
        // Encolar: pulsar Supr rápido ya no pierde borrados.
        if (delProc.running) {
            pendingDeleteQueue.push(id);
            return;
        }
        startDelete(id);
    }

    function startDelete(id) {
        // NOTA: antes era `cliphist delete-query <id>`, que borra POR
        // CONTENIDO (todo lo que contenga ese texto) y podía borrar
        // varias entradas ajenas o ninguna. Lo correcto para un id es
        // `echo <id> | cliphist delete`.
        delProc.command = ["sh", "-c", "printf '%s' '" + shEscape(id) + "' | cliphist delete"];
        // Guardamos el id en curso para limpiar su preview al terminar.
        delProc.currentId = id;
        delProc.running = true;
    }

    function wipe() {
        wipeProc.running = true;
    }

    // Tope de 40 previews en caché (las entradas viejas se regeneran solas).
    Process {
        id: trimProc

        command: ["sh", "-c", "d='" + root.previewDir + "'; n=$(ls -t \"$d\" 2>/dev/null | wc -l); if [ \"$n\" -gt 40 ]; then ls -t \"$d\" | tail -n +41 | (cd \"$d\" && xargs -r rm -f); fi"]
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.previewDir]
        Component.onCompleted: mkdirProc.running = true
    }

    // cliphist list -> "<id>\t<preview>"
    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "" || line.startsWith("opening db"))
                    return;
                const tab = line.indexOf("\t");
                if (tab < 0)
                    return;
                const cid = line.slice(0, tab).trim();
                const txt = line.slice(tab + 1).trim();
                const isImg = txt.indexOf("[[ binary data") === 0;
                root.entries.append({
                    cid: cid,
                    text: isImg ? ("Imagen · " + cid) : txt,
                    raw: txt,
                    isImage: isImg
                });
            }
        }
        onExited: (code, status) => {
            root.refreshing = false;
            root.ready = true;
            if (code !== 0 && root.entries.count === 0)
                root.error = I18nService.getTranslation("launcher.clipboard_error", "Sin historial (¿daemon cliphist activo?)");
            root.rebuildSnapshot();
            if (!trimProc.running)
                trimProc.running = true;
            // Refresh pedido mientras listábamos (ej. Supr durante refresh).
            if (root.pendingRefresh) {
                root.pendingRefresh = false;
                // diferir un tick para no reentrar en el mismo onExited
                Qt.callLater(() => root.refresh());
            }
        }
    }

    Process {
        id: copyProc
        onExited: (code, status) => {
            if (code !== 0)
                Log.warn("ClipboardService: copy falló id=" + root.copyId);
            // Si se pidió otra copia mientras tanto, ejecuta solo la última.
            if (root.hasPendingCopy) {
                const nid = root.pendingCopyId;
                const nimg = root.pendingCopyIsImage;
                root.hasPendingCopy = false;
                root.pendingCopyId = "";
                root.startCopy(nid, nimg);
            }
        }
    }

    Process {
        id: previewProc
        onExited: (code, status) => {
            const finishedId = root.previewId;
            if (code === 0)
                root.previewReady(finishedId);
            else {
                Log.warn("ClipboardService: preview falló id=" + finishedId);
                root.previewFailed(finishedId);
            }
            // Navegación rápida: atiende el último preview pendiente. Solo
            // si no hay pendiente corre el prefetch (nunca le quita el
            // turno a lo real).
            if (root.pendingPreviewId !== "") {
                const nid = root.pendingPreviewId;
                root.pendingPreviewId = "";
                root.startPreview(nid);
            } else {
                root._pumpPreview();
            }
        }
    }

    Process {
        id: textProc
        stdout: SplitParser {
            onRead: data => {
                if (root.textAcc.length < 20000)
                    root.textAcc += data + "\n";
            }
        }
        onExited: (code, status) => {
            if (code === 0) {
                let t = root.textAcc;
                if (t.endsWith("\n"))
                    t = t.slice(0, -1);
                // head -c cortó: el acumulador llegó al tope.
                if (root.textAcc.length >= 20000)
                    t += "\n…";
                root.textContent = t;
            } else {
                Log.warn("ClipboardService: texto falló id=" + root.textCid);
                root.textContent = "";
            }
            root.textReady(root.textCid);
            // Navegación rápida: atiende el último texto pendiente.
            if (root.pendingTextId !== "") {
                const nid = root.pendingTextId;
                root.pendingTextId = "";
                root.startTextRequest(nid);
            }
        }
    }

    Process {
        id: delProc
        property string currentId: ""
        onExited: (code, status) => {
            if (code !== 0)
                Log.warn("ClipboardService: delete falló id=" + delProc.currentId);
            else if (delProc.currentId !== "")
                // Limpia el preview cacheado de la entrada borrada para
                // no mostrar una imagen fantasma si el id se recicla.
                cleanProc.clean(delProc.currentId);
            delProc.currentId = "";
            if (root.pendingDeleteQueue.length > 0) {
                root.startDelete(root.pendingDeleteQueue.shift());
                return;
            }
            root.refresh();
        }
    }

    Process {
        id: cleanProc
        // Borrado puntual de un preview; sin señales, no interfiere.
        function clean(cid) {
            cleanProc.command = ["sh", "-c", "rm -f '" + root.shEscape(root.previewDir) + "/preview-" + root.shEscape(String(cid).trim()) + ".png'"];
            cleanProc.running = true;
        }
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }
}
