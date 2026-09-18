// --- FilePreviewService (Singleton) ---
// Miniaturas para el modo archivos del launcher:
//   audio → carátula incrustada (ffmpeg, mjpeg)
//   video → fotograma (ffmpegthumbnailer)
//   pdf   → primera página (pdftoppm, poppler)
//   imagen → se muestra directa (no pasa por aquí)
// Caché en /tmp/qs-filepreview/<sha>.jpg (clave = ruta+mtime+tamaño,
// tope 60 ficheros; los pdf usan .png). El shell resuelve la ruta final
// y la devuelve por stdout (QSOUT:). Peticiones rápidas seguidas: solo
// gana la última.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "ShellUtils.js" as ShellUtils

Singleton {
    id: root

    readonly property string cacheDir: "/tmp/qs-filepreview"

    property string reqPath: ""
    property string resolvedOut: ""
    property string pendingPath: ""
    property string pendingKind: ""

    signal ready(string path, string image)
    signal textReady(string path, string text)

    // Escape común (ver ShellUtils.js, única implementación en Launcher).

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
            extract = "ffmpeg -y -v error -i '" + p + "' -an -vcodec mjpeg \"" + out + "\" 2>/dev/null";
        else if (kind === "pdf")
            extract = "pdftoppm -png -f 1 -l 1 -singlefile -r 100 '" + p + "' \"" + base + "\" 2>/dev/null";
        else
            extract = "ffmpegthumbnailer -i '" + p + "' -o \"" + out + "\" -s 512 2>/dev/null";
        return "mkdir -p '" + root.cacheDir + "' && OUT=" + out + " && ([ -s \"$OUT\" ] || " + extract + ") && echo \"QSOUT:$OUT\"" + trimSnippet();
    }

    property string textReqPath: ""
    property string textAcc: ""
    property bool textRestart: false

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
        }
    }
}
