// --- FilePreviewService (Singleton) ---
// Miniaturas para el modo archivos del launcher:
//   audio → carátula incrustada (ffmpeg, mjpeg, acotada a 512px)
//   video → fotograma (ffmpegthumbnailer, 384px: el panel muestra 340)
//   pdf   → primera página (pdftoppm, 72 dpi: sobra para 340px)
//   imagen → se muestra directa (no pasa por aquí)
// Caché en /tmp/qs-filepreview/<sha>.jpg (clave = ruta+mtime+tamaño,
// tope 60 ficheros; los pdf usan .png). El shell resuelve la ruta final
// y la devuelve por stdout (QSOUT:). Peticiones rápidas seguidas: solo
// gana la última.
// Además: prefetch de vecinos (cola de baja prioridad: la petición actual
// siempre pasa delante) y metadatos de audio vía ffprobe (título, artista,
// álbum, duración) para mostrar en el panel.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Base/ShellUtils.js" as ShellUtils

Singleton {
    id: root

    readonly property string cacheDir: "/tmp/qs-filepreview"

    property string reqPath: ""
    property string resolvedOut: ""
    property string pendingPath: ""
    property string pendingKind: ""

    signal ready(string path, string image)
    signal textReady(string path, string text)
    // Metadatos de audio (tags + duración en segundos, "" si no hay).
    signal metaReady(string path, string title, string artist, string album, string duration)

    // Cola de prefetch (baja prioridad): [path, kind]. Se reemplaza en
    // cada highlight (solo importan los vecinos actuales) y la petición
    // real siempre pasa delante: request() mata lo en curso y onExited
    // atiende pending antes de bombear la cola.
    property var prefetchQueue: []

    function prefetchNeighbors(pairs) {
        const out = [];
        for (let i = 0; i < pairs.length && out.length < 6; i++) {
            const p = pairs[i][0];
            const k = pairs[i][1];
            if (!p || p === root.reqPath || p === root.pendingPath)
                continue;
            let dup = false;
            for (let j = 0; j < out.length; j++)
                if (out[j][0] === p) {
                    dup = true;
                    break;
                }
            if (!dup)
                out.push([p, k]);
        }
        root.prefetchQueue = out;
        root._pumpPrefetch();
    }

    function clearPrefetch() {
        root.prefetchQueue = [];
    }

    function _pumpPrefetch() {
        // Igual que en ClipboardService: el Process va por id directo
        // (root.coverProc sería undefined y abortaría update()).
        if (coverProc.running || root.pendingPath !== "")
            return;
        if (root.prefetchQueue.length === 0)
            return;
        const job = root.prefetchQueue[0];
        root.prefetchQueue = root.prefetchQueue.slice(1);
        root.startRequest(job[0], job[1]);
    }

    // Escape común (ver Base/ShellUtils.js, única implementación en Launcher).

    function trimSnippet() {
        return "; d='" + root.cacheDir + "'; n=$(ls -t \"$d\" 2>/dev/null | wc -l); if [ \"$n\" -gt 60 ]; then ls -t \"$d\" | tail -n +61 | (cd \"$d\" && xargs -r rm -f); fi";
    }

    function extractShell(path, kind) {
        const p = ShellUtils.shellEscape(path);
        const key = "$(echo -n '" + p + "|'$(stat -c '%Y %s' '" + p + "' 2>/dev/null) | sha256sum | cut -c1-16)";
        const base = root.cacheDir + "/" + key;
        // pdftoppm añade la extensión él mismo (-singlefile): el OUT final
        // es .png; audio/video generan el .jpg.
        const out = kind === "pdf" ? base + ".png" : base + ".jpg";
        let extract = "";
        if (kind === "audio")
            extract = "ffmpeg -y -v error -i '" + p + "' -an -vf scale=512:-1 -vcodec mjpeg \"" + out + "\" 2>/dev/null";
        else if (kind === "pdf")
            extract = "pdftoppm -png -f 1 -l 1 -singlefile -r 72 '" + p + "' \"" + base + "\" 2>/dev/null";
        else
            extract = "ffmpegthumbnailer -i '" + p + "' -o \"" + out + "\" -s 384 2>/dev/null";
        return "mkdir -p '" + root.cacheDir + "' && OUT=" + out + " && ([ -s \"$OUT\" ] || " + extract + ") && echo \"QSOUT:$OUT\"" + trimSnippet();
    }

    property string textReqPath: ""
    property string textAcc: ""
    property bool textRestart: false

    // Último resultado de metadatos (para servir de caché inmediata si se
    // vuelve al mismo tema sin salir del modo).
    property string metaDonePath: ""
    property var metaDone: null
    property string metaReqPath: ""
    property string metaAcc: ""
    property bool metaRestart: false
    property string pendingMetaPath: ""

    // Metadatos del tema (tags + duración). Emite metaReady siempre (con
    // strings vacíos si no hay tags): el display decide qué pintar.
    function requestMeta(path) {
        if (!path)
            return;
        if (path === root.metaDonePath && root.metaDone) {
            root.metaReady(path, root.metaDone.title, root.metaDone.artist, root.metaDone.album, root.metaDone.duration);
            return;
        }
        // Igual que el texto: superseder matando (el onExited del muerto
        // retoma con lo último pedido).
        if (metaProc.running) {
            root.pendingMetaPath = path;
            root.metaRestart = true;
            metaProc.running = false;
            return;
        }
        root.startMeta(path);
    }

    function startMeta(path) {
        root.metaReqPath = path;
        root.metaAcc = "";
        root.pendingMetaPath = "";
        root.metaRestart = false;
        metaProc.command = ["sh", "-c", "ffprobe -v error -print_format json -show_format '" + ShellUtils.shellEscape(path) + "' 2>/dev/null"];
        metaProc.running = true;
    }

    // Las claves de tags varían en mayúsculas según el contenedor
    // (TITLE/title/TIT2...): se normaliza a minúsculas.
    function parseMeta(jsonText) {
        const info = { title: "", artist: "", album: "", duration: "" };
        try {
            const json = JSON.parse(jsonText);
            const tags = (json && json.format && json.format.tags) || {};
            const norm = {};
            for (const k in tags)
                norm[String(k).toLowerCase()] = String(tags[k]);
            info.title = norm["title"] || "";
            info.artist = norm["artist"] || norm["album_artist"] || "";
            info.album = norm["album"] || "";
            const d = parseFloat(json && json.format && json.format.duration);
            info.duration = isNaN(d) ? "" : String(Math.round(d));
        } catch (e) {
        }
        return info;
    }

    // Texto: primeras líneas (tope 200 KB) para previsualizar ficheros .txt/.md/…
    function requestText(path) {
        const p = ShellUtils.shellEscape(path);
        textReqPath = path;
        textAcc = "";
        // Navegando rápido se solapan lecturas y el onExited tardío pintaría
        // texto de otro fichero: se mata y se reintenta al morir (finished
        // también se emite al matar).
        if (textProc.running) {
            textRestart = true;
            textProc.running = false;
            return;
        }
        textRestart = false;
        textProc.command = ["sh", "-c", "f='" + p + "'; sz=$(stat -c %s \"$f\" 2>/dev/null || echo 0); if [ \"$sz\" -gt 204800 ]; then echo 'QSTEXT_TOO_BIG'; else head -c 6000 \"$f\" 2>/dev/null; fi"];
        textProc.running = true;
    }

    function request(path, kind) {
        if (path === reqPath && coverProc.running)
            return;
        // Un scroll rápido no acumula ffmpeg/thumbnailer en paralelo: se
        // mata lo en curso y la última petición gana al morir (finished
        // también se emite al matar y onExited retoma el pendiente).
        if (coverProc.running) {
            pendingPath = path;
            pendingKind = kind;
            coverProc.running = false;
            return;
        }
        startRequest(path, kind);
    }

    function startRequest(path, kind) {
        reqPath = path;
        resolvedOut = "";
        pendingPath = "";
        pendingKind = "";
        coverProc.command = ["sh", "-c", extractShell(path, kind)];
        coverProc.running = true;
    }

    Process {
        id: textProc

        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "QSTEXT_TOO_BIG") {
                    root.textAcc = "QSTEXT_TOO_BIG";
                    return;
                }
                if (root.textAcc.length < 6000)
                    root.textAcc += data + "\n";
            }
        }

        onExited: (code, status) => {
            // Muerte provocada por requestText() para superseder: reintenta
            // con la última ruta pedida en vez de pintar texto ajeno.
            if (root.textRestart) {
                root.textRestart = false;
                root.requestText(root.textReqPath);
                return;
            }
            root.textReady(root.textReqPath, root.textAcc);
        }
    }

    Process {
        id: metaProc

        stdout: SplitParser {
            onRead: data => {
                root.metaAcc += data + "\n";
            }
        }

        onExited: (code, status) => {
            // Muerte provocada por requestMeta() para superseder.
            if (root.metaRestart) {
                root.metaRestart = false;
                root.requestMeta(root.pendingMetaPath !== "" ? root.pendingMetaPath : root.metaReqPath);
                return;
            }
            const donePath = root.metaReqPath;
            if (code === 0 && root.metaAcc.trim() !== "") {
                const info = root.parseMeta(root.metaAcc);
                root.metaDonePath = donePath;
                root.metaDone = info;
                root.metaReady(donePath, info.title, info.artist, info.album, info.duration);
            } else {
                root.metaDonePath = donePath;
                root.metaDone = { title: "", artist: "", album: "", duration: "" };
                root.metaReady(donePath, "", "", "", "");
            }
        }
    }

    Process {
        id: coverProc

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.startsWith("QSOUT:"))
                    root.resolvedOut = line.slice(6).trim();
            }
        }

        onExited: (code, status) => {
            const donePath = root.reqPath;
            if (root.pendingPath !== "") {
                const p = root.pendingPath;
                const k = root.pendingKind;
                root.startRequest(p, k);
                return;
            }
            if (code === 0 && root.resolvedOut !== "")
                root.ready(donePath, root.resolvedOut);
            else
                root.ready(donePath, "");
            // El actual ya está servido: sigue el prefetch si lo hay.
            root._pumpPrefetch();
        }
    }
}
