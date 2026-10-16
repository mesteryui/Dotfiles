pragma Singleton

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

// Frame estático por vídeo: UNA sola captura por fondo, compartida por el
// poster del fondo animado, la pantalla de bloqueo y matugen.
//
// - Nombre determinista: el mismo vídeo siempre mapea al mismo archivo
//   (`framesDir/<hash(ruta)>.jpg`), en State (no en cache: el lockscreen y
//   el tema dependen de él y un `rm -rf ~/.cache` no debe romperlos).
// - Sin reescrituras: el script es idempotente (si el frame existe y es más
//   nuevo que el vídeo, sale 0 sin tocar el disco), así que alternar entre
//   fondos no regenera nada.
// - Cola serializada: un solo ffmpeg a la vez aunque muchas miniaturas lo
//   pidan a la vez (apertura del menú con N vídeos).
Singleton {
    id: root

    readonly property string framesDir: Directories.state + "/quickshell/wallpaper-frames"
    readonly property string extractScript: Directories.config
                                            + "/quickshell/scripts/extract-wallpaper-frame.sh"

    // Vídeo en vuelo + cola (rutas absolutas). Solo el último estado gana en
    // cada consumidor vía frameReady; aquí no se descarta nada: cada vídeo
    // pedido termina con su frame listo.
    property var queue: []
    property string currentVideo: ""
    // Vídeos ya resueltos en esta sesión (video -> frame). Evita
    // re-extracciones desde re-evaluaciones y handlers repetidos.
    // Acotado a ~20 entradas (LRU por orden de inserción): sin cota, abrir
    // el menú muchas veces retenía un mapa siempre creciente. Al podar se
    // olvida la confirmación, no el fichero: re-pedirlo revalida en disco
    // sin reescribir si sigue vigente (el script es idempotente).
    // REGLA: ensureFrame solo se llama desde funciones/handlers, NUNCA
    // dentro de la evaluación de un binding (escribir en queue/proc desde
    // un binding dispara "Binding loop detected"). Tras confirmar,
    // ensureFrame es no-op.
    property var confirmed: ({})
    readonly property int confirmedCap: 20

    signal frameReady(videoPath: string, framePath: string)

    // Watchdog: ffmpeg no debe wedgar la cola. Con timeout + kill según la
    // regla de robustez del repo (todo Process con timeout explícito).
    property Timer extractWatchdog: Timer {
        interval: 60000
        onTriggered: {
            if (root.proc.running) {
                console.warn("[Video] timeout extrayendo frame, mato ffmpeg: " + root.currentVideo);
                root.proc.running = false;
            }
        }
    }

    property Process proc: Process {
        onExited: exitCode => {
            root.extractWatchdog.stop();
            const done = root.currentVideo;
            const frame = done !== "" ? root.frameFor(done) : "";
            root.currentVideo = "";
            if (exitCode === 0 && done !== "" && frame !== "") {
                const c = root.confirmed;
                c[done] = frame;
                // Poda LRU: las claves de objeto conservan orden de
                // inserción; reasignar una existente la mantiene, así que
                // basta con soltar las más viejas por delante.
                const keys = Object.keys(c);
                while (keys.length > root.confirmedCap) {
                    const oldest = keys.shift();
                    delete c[oldest];
                }
                root.confirmed = c;
                root.frameReady(done, frame);
            } else if (done !== "") {
                console.warn("[Video] no se pudo extraer frame de: " + done);
            }
            root.pump();
        }
    }

    // Hash cyrb53 de la ruta absoluta → hex. Determinista en esta máquina:
    // el mismo archivo siempre da el mismo frame, sin leer su contenido.
    function hashPath(s: string): string {
        let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
        for (let i = 0; i < s.length; i++) {
            const ch = s.charCodeAt(i);
            h1 = Math.imul(h1 ^ ch, 2654435761);
            h2 = Math.imul(h2 ^ ch, 1597334677);
        }
        h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
        h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
        return (h2 >>> 0).toString(16).padStart(8, "0") + (h1 >>> 0).toString(16).padStart(8, "0");
    }

    function frameFor(videoPath: string): string {
        if (!videoPath)
            return "";
        return root.framesDir + "/" + root.hashPath(String(videoPath)) + ".jpg";
    }

    // Pide el frame; el script no reescribe si ya está vigente. Emite
    // frameReady al terminar (los consumidores ya muestran el frame como
    // Image: si aún no existe en disco, aparece al generarse por el binding).
    // Idempotente por sesión: un vídeo confirmado no se re-extrae (ver
    // `confirmed`). Con force=true se revalida en disco (el script sigue sin
    // reescribir si el frame está vigente): para intenciones nuevas
    // explícitas (aplicar fondo), no para re-evaluaciones de bindings.
    function ensureFrame(videoPath: string, force: bool) {
        const video = String(videoPath || "");
        if (video === "")
            return;
        if (!force && root.confirmed[video] !== undefined)
            return;
        if (video === root.currentVideo)
            return;
        if (root.queue.includes(video))
            return;
        root.queue.push(video);
        root.queueChanged();
        root.pump();
    }

    function pump() {
        if (root.proc.running || root.currentVideo !== "" || root.queue.length === 0)
            return;
        const next = root.queue.shift();
        root.queueChanged();
        root.currentVideo = next;
        root.proc.command = ["bash", root.extractScript, next, root.frameFor(next)];
        root.proc.running = true;
        root.extractWatchdog.restart();
    }
}
