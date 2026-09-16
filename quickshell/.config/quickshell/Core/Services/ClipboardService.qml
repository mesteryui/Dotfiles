// --- ClipboardService (Singleton) ---
// Historial del portapapeles vía cliphist (mismo backend que Walker/Elephant
// esperan: `cliphist list | decode | delete-query | wipe` + `wl-copy`).
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
    property string delQuery: ""

    signal previewReady(string cid)

    function refresh() {
        if (listProc.running)
            return;
        entries.clear();
        snapshot = [];
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
        copyId = String(cid);
        copyIsImage = isImage;
        copyProc.running = true;
    }

    // Devuelve la ruta donde quedará el preview (emite previewReady al terminar)
    function previewImage(cid) {
        previewId = String(cid);
        previewProc.running = true;
        return previewDir + "/preview-" + previewId + ".png";
    }

    function deleteEntry(cid) {
        delQuery = String(cid);
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
                root.error = I18nService.getTranslation("launcher.empty_clipboard_error", "Sin historial (¿daemon cliphist activo?)");
            root.rebuildSnapshot();
            if (!trimProc.running)
                trimProc.running = true;
        }
    }

    Process {
        id: copyProc
        command: root.copyIsImage
            ? ["sh", "-c", "cliphist decode " + root.copyId + " | wl-copy --type image/png"]
            : ["sh", "-c", "cliphist decode " + root.copyId + " | wl-copy"]
        onExited: (code, status) => {
            if (code !== 0)
                console.warn("ClipboardService: copy falló id=" + root.copyId);
        }
    }

    Process {
        id: previewProc
        // Si el PNG ya existe y no está vacío se reutiliza: el decode solo
        // ocurre la primera vez (acelera las miniaturas al navegar).
        command: ["sh", "-c", "mkdir -p " + root.previewDir + " && OUT=" + root.previewDir + "/preview-" + root.previewId + ".png && ([ -s \"$OUT\" ] || cliphist decode " + root.previewId + " > \"$OUT\")"]
        onExited: (code, status) => {
            if (code === 0)
                root.previewReady(root.previewId);
            else
                console.warn("ClipboardService: preview falló id=" + root.previewId);
        }
    }

    Process {
        id: delProc
        command: ["cliphist", "delete-query", root.delQuery]
        onExited: root.refresh()
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }
}
