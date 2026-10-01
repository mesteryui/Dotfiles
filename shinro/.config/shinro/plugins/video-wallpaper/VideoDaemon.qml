// Daemon video-wallpaper (capability "video-wallpaper-backend").
// Motor de fondos animados: mpvpaper por salida ALL, con frame→matugen
// vía WallpaperService y pausa del backend estático (awww).
// Raíz Item no visible (QtObject no admite hijos: workers directos).
// Ver PLUGINS.md § capacidades funcionales.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Modules
import qs.Core.Services as Services

Item {
    id: root

    property var plugin
    visible: false

    readonly property string pluginId: "video-wallpaper"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Services.Directories.home + "/.cache") + "/shinro/video-thumbs"

    property string currentVideo: ""
    // Activo = sonando (lo lee WallpaperService.ensureBackend).
    readonly property bool active: root.currentVideo !== ""
    // Petición en vuelo (play/stop la pisan: solo gana la última).
    property string pendingVideo: ""
    property bool pendingSkipFrame: false
    property string pendingFrame: ""
    // true mientras se aborta trabajo en curso para atender lo último.
    property bool switching: false
    property bool stopping: false
    property int frameAttempt: 0
    property string stagedVideo: ""

    // Miniaturas: id -> ruta (éxito) / fallidas (sesión). Avisos vía bump.
    property var thumbKnown: ({})
    property var thumbFailed: ({})
    property var thumbQueue: []

    function defaults() {
        return { video_directory: "", mute: true, hardware_decode: true, auto_pause: true, mpv_options: "", resume_on_boot: true };
    }

    function settings() {
        const d = Services.PluginService.getData(root.pluginId) || ({});
        return Object.assign(root.defaults(), d.settings || ({}));
    }

    function videoDir() {
        const s = root.settings();
        if (s.video_directory !== "")
            return s.video_directory;
        return Services.WallpaperService.wallpaperDir;
    }

    function fullPath(p) {
        const s = String(p || "");
        if (s.startsWith("/"))
            return s;
        const d = root.videoDir();
        return d + (d.endsWith("/") ? "" : "/") + s;
    }

    function baseKey(p) {
        const base = String(p).split("/").pop().replace(/[^a-zA-Z0-9.]/g, "_");
        return base.length > 80 ? base.slice(-80) : base;
    }

    Component.onCompleted: {
        mkdirProc.running = true;
        // Reanudar: el vídeo persistido vuelve solo (sin regenerar tema;
        // el tema persistido ya se aplicó al arrancar).
        const d = Services.PluginService.getData(root.pluginId) || ({});
        if (d.currentVideo && root.settings().resume_on_boot !== false)
            Qt.callLater(() => root.playVideo(d.currentVideo, true));
    }

    // Al morir (disable/rescan/salida) con vídeo sonando: deshacer fuera
    // (execDetached sobrevive al objeto): awww de vuelta si murió +
    // estático restaurado. stopVideo() normal ya lo hace en vivo con
    // restore; esto es la red (con espera a que el daemon escuche).
    Component.onDestruction: {
        if (root.currentVideo !== "") {
            const stat = Persistent.persistence.currentWallpaper || "";
            Quickshell.execDetached(["sh", "-c",
                "pgrep -x awww-daemon >/dev/null || awww-daemon >/dev/null 2>&1 & " +
                "for i in 1 2 3 4 5 6; do pgrep -x awww-daemon >/dev/null && break; sleep 0.5; done" +
                (stat !== "" ? "; qs ipc call wallpaper restore" : "")]);
        }
    }

    Process {
        id: mkdirProc

        command: ["mkdir", "-p", root.cacheDir]
    }

    // Entrada del core agnóstico (capability wallpaper-backend):
    // reproducir este fondo. El core no sabe qué formato es.
    function applyWallpaper(path) {
        root.playVideo(path);
    }

    // ---------- reproducción (máquina de estados) ----------
    // playVideo solo REGISTRA la petición y patea lo que haya en curso;
    // las continuaciones (onExited) retoman con startPendingVideo().
    // Invariantes: startPendingVideo no hace nada si no hay pendiente o
    // hay extracción en curso; beginPlayback consume pendingVideo.
    function playVideo(path, skipFrame) {
        const video = root.fullPath(path);
        if (video === "")
            return;
        root.pendingVideo = video;
        root.pendingSkipFrame = !!skipFrame;
        root.switching = mpvProc.running || frameProc.running || killProc.running;
        Services.PluginService.clearError(root.pluginId);
        if (mpvProc.running) {
            root.stopping = true;
            mpvProc.running = false;
        }
        if (frameProc.running)
            frameProc.running = false;
        if (root.switching)
            return;
        root.startPendingVideo();
    }

    function startPendingVideo() {
        const video = root.pendingVideo;
        if (video === "" || frameProc.running)
            return;
        if (root.pendingSkipFrame) {
            root.pendingSkipFrame = false;
            root.beginPlayback();
            return;
        }
        root.frameAttempt = 1;
        root.startFrameExtract();
    }

    function framePathFor(video) {
        return root.cacheDir + "/frame-" + root.baseKey(video) + ".jpg";
    }

    function startFrameExtract() {
        // -ss 1 evita el primer frame negro; si el clip es más corto,
        // el fallo reintenta con -ss 0 (ver frameProc).
        const ss = root.frameAttempt === 1 ? "1" : "0";
        frameProc.command = ["ffmpeg", "-y", "-v", "error", "-ss", ss, "-i", root.pendingVideo, "-vframes", "1", "-q:v", "2", root.framePathFor(root.pendingVideo)];
        frameProc.running = true;
    }

    Process {
        id: frameProc

        onExited: code => {
            if (root.switching) {
                root.switching = false;
                root.startPendingVideo();
                return;
            }
            const video = root.pendingVideo;
            if (video === "")
                return;
            if (code !== 0) {
                if (root.frameAttempt === 1) {
                    root.frameAttempt = 2;
                    root.startFrameExtract();
                    return;
                }
                root.pendingVideo = "";
                Services.PluginService.noteError(root.pluginId, "no se pudo leer el vídeo");
                return;
            }
            // Frame listo: póster estático (awww + matugen, sin
            // persistir) y al confirmarse (changed) se pasa al vídeo.
            root.pendingFrame = root.framePathFor(video);
            Services.WallpaperService.applyPosterFrame(root.pendingFrame);
        }
    }

    Connections {
        target: Services.WallpaperService

        function onChanged(p) {
            if (root.pendingVideo === "")
                return;
            if (p === root.pendingFrame && root.pendingFrame !== "") {
                root.pendingFrame = "";
                root.beginPlayback();
            } else {
                // El usuario aplicó otro fondo a mitad: abortar.
                root.pendingVideo = "";
                root.pendingFrame = "";
            }
        }
    }

    function beginPlayback() {
        const video = root.pendingVideo;
        root.pendingVideo = "";
        root.pendingSkipFrame = false;
        if (video === "")
            return;
        root.stagedVideo = video;
        killProc.running = true;
    }

    Process {
        id: killProc

        // awww fuera del todo: pausado seguiría dibujando el frame
        // congelado encima/debajo del vídeo según el orden de capas.
        // Sin awww no hay estático posible (solo negro ~300ms).
        command: ["awww", "kill"]
        onExited: code => {
            if (root.switching) {
                root.switching = false;
                root.startPendingVideo();
                return;
            }
            if (code !== 0)
                console.warn("[video-wallpaper] awww kill falló (" + code + "), se sigue igual");
            root.startMpv(root.stagedVideo);
        }
    }

    function mpvOptions() {
        const s = root.settings();
        const o = [];
        if (s.mute !== false)
            o.push("no-audio");
        o.push("loop");
        // Pantalla completa real (recorta preserved-aspect) + cero chrome:
        // sin OSD, sin OSC, sin nada que delate la reproducción.
        o.push("panscan=1.0", "osd-level=0", "osc=no");
        if (s.hardware_decode !== false)
            o.push("hwdec=auto");
        if (s.mpv_options !== "")
            o.push(s.mpv_options);
        return o.join(" ");
    }

    function startMpv(video) {
        if (video === "")
            return;
        // Preflight: si el binario falta, onExited NUNCA se dispara
        // (solo WARN "failed to start") y el estado quedaría colgado
        // en "playing". Sin caché a propósito: si instalas mpvpaper
        // a mitad de sesión, el siguiente play ya funciona.
        mpvCheckProc.running = true;
    }

    Process {
        id: mpvCheckProc

        command: ["sh", "-c", "command -v mpvpaper"]
        onExited: code => {
            if (code !== 0) {
                Services.PluginService.noteError(root.pluginId, "mpvpaper no instalado (sudo pacman -S mpvpaper)");
                const d = Services.PluginService.getData(root.pluginId) || ({});
                d.currentVideo = "";
                Services.PluginService.setData(root.pluginId, d);
                root.currentVideo = "";
                // Queda el frame como estático coherente con el tema.
                launchProc.restoreAfter = false;
                if (!launchProc.running)
                    launchProc.running = true;
                return;
            }
            root.reallyStartMpv(root.stagedVideo);
        }
    }

    function reallyStartMpv(video) {
        if (video === "")
            return;
        const s = root.settings();
        const cmd = ["mpvpaper"];
        if (s.auto_pause !== false)
            cmd.push("-p");
        cmd.push("-o", root.mpvOptions(), "ALL", video);
        mpvProc.command = cmd;
        mpvProc.running = true;
        mpvWatchdog.restart();
        root.currentVideo = video;
        const d = Services.PluginService.getData(root.pluginId) || ({});
        d.currentVideo = video;
        Services.PluginService.setData(root.pluginId, d);
        Services.PluginService.clearError(root.pluginId);
    }

    Process {
        id: mpvProc

        onExited: code => {
            mpvWatchdog.stop();
            if (root.stopping) {
                root.stopping = false;
                if (root.switching) {
                    root.switching = false;
                    root.startPendingVideo();
                }
                return;
            }
            // Muerte inesperada: se vuelve al estático (daemon+restore) y
            // se avisa. Queda el error visible hasta el próximo play bueno.
            root.currentVideo = "";
            const d = Services.PluginService.getData(root.pluginId) || ({});
            d.currentVideo = "";
            Services.PluginService.setData(root.pluginId, d);
            const msg = code === 127 ? "mpvpaper no instalado (sudo pacman -S mpvpaper)" : "mpvpaper terminó (" + code + ")";
            Services.PluginService.noteError(root.pluginId, msg);
            launchProc.restoreAfter = true;
            if (!launchProc.running)
                launchProc.running = true;
            // No se abandona la petición en vuelo (si la hay).
            root.startPendingVideo();
        }
    }

    Timer {
        id: mpvWatchdog

        interval: 15000
        onTriggered: {
            if (mpvProc.running)
                console.warn("[video-wallpaper] mpvpaper tarda en arrancar, se sigue esperando");
        }
    }

    function stopVideo(restoreStatic) {
        root.pendingVideo = "";
        root.pendingFrame = "";
        root.pendingSkipFrame = false;
        root.switching = false;
        const d = Services.PluginService.getData(root.pluginId) || ({});
        d.currentVideo = "";
        Services.PluginService.setData(root.pluginId, d);
        root.currentVideo = "";
        Services.PluginService.clearError(root.pluginId);
        root.stopping = true;
        if (mpvProc.running)
            mpvProc.running = false;
        else
            root.stopping = false;
        if (frameProc.running)
            frameProc.running = false;
        launchProc.restoreAfter = restoreStatic !== false;
        if (!launchProc.running)
            launchProc.running = true;
    }

    Process {
        id: launchProc

        // awww de vuelta (si no vive) + estático restaurado.
        property bool restoreAfter: true
        command: ["sh", "-c", "pgrep -x awww-daemon >/dev/null || { awww-daemon >/dev/null 2>&1 & sleep 1; }"]
        onExited: {
            if (launchProc.restoreAfter)
                Services.WallpaperService.restore();
        }
    }

    // ---------- miniaturas (capability) ----------
    // Lectura PURA (sin efectos: apta para bindings) + petición explícita.
    // La card pide una vez (onCompleted/cambio de fichero) y lee el caché
    // reaccionando a bumpThumbs(). Mutar la cola dentro del binding
    // provocaba "Binding loop detected".
    function cachedThumbnail(videoPath) {
        const key = root.baseKey(root.fullPath(videoPath));
        if (root.thumbKnown[key])
            return root.thumbKnown[key];
        return "";
    }

    function requestThumbnail(videoPath) {
        const video = root.fullPath(videoPath);
        if (video === "")
            return;
        const key = root.baseKey(video);
        if (root.thumbKnown[key] || root.thumbFailed[key])
            return;
        const pending = root.thumbQueue;
        for (let i = 0; i < pending.length; i++)
            if (pending[i].key === key)
                return;
        root.thumbQueue = pending.concat([{ key: key, video: video, thumb: root.cacheDir + "/thumb-" + key + ".jpg" }]);
        root.pumpThumbs();
    }

    // Compat: primera llamada pide + devuelve caché (una sola vez por
    // pareja path/sesión gracias a known/failed/queued).
    function thumbnailFor(videoPath) {
        root.requestThumbnail(videoPath);
        return root.cachedThumbnail(videoPath);
    }

    function pumpThumbs() {
        if (thumbProc.running || root.thumbQueue.length === 0)
            return;
        const job = root.thumbQueue[0];
        root.thumbQueue = root.thumbQueue.slice(1);
        thumbProc.currentKey = job.key;
        thumbProc.currentThumb = job.thumb;
        thumbProc.command = ["ffmpegthumbnailer", "-i", job.video, "-o", job.thumb, "-s", "384"];
        thumbProc.running = true;
    }

    Process {
        id: thumbProc

        property string currentKey: ""
        property string currentThumb: ""
        onExited: code => {
            const key = thumbProc.currentKey;
            if (key === "")
                return;
            if (code === 0) {
                const known = Object.assign({}, root.thumbKnown);
                known[key] = thumbProc.currentThumb;
                root.thumbKnown = known;
                Services.WallpaperService.bumpThumbs();
            } else {
                const failed = Object.assign({}, root.thumbFailed);
                failed[key] = true;
                root.thumbFailed = failed;
            }
            thumbProc.currentKey = "";
            root.pumpThumbs();
        }
    }

    IpcHandler {
        target: "video-wallpaper"

        function play(path: string): void {
            root.playVideo(path || "");
        }

        function stop(): void {
            root.stopVideo(true);
        }

        function status(): string {
            return JSON.stringify({ playing: root.currentVideo, pending: root.pendingVideo });
        }
    }
}
