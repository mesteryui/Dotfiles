pragma Singleton

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Fuente para matugen: el wallpaper persistido (imagen directa) o el
    // frame estatico si es un video (matugen no lee video).
    readonly property string currentWallpaper: Persistent.persistence.currentWallpaper
    readonly property string matugenMode: ConfigService.configs.appearance.darkMode ? "dark" : "light"
    readonly property string matugenType: ConfigService.configs.appearance.matugen.type
    readonly property bool busy: proc.running

    // Última petición aplicada con éxito: evita regenerar la misma
    // entrada (init() + changed() duplicados, toggles redundantes...).
    property string lastWallpaper: ""
    property string lastMode: ""
    property string lastType: ""
    property bool hasGenerated: false

    // Petición en espera mientras hay una en vuelo (solo la última gana).
    // No se mata el proceso en curso: abortar matugen a mitad de
    // escritura deja plantillas a medias.
    property string pending: ""
    property bool hasPending: false

    // Watchdog: matugen suele tardar segundos; si se cuelga no debe wedgar
    // el tema para siempre. Tras 2 timeouts seguidos deja de reintentar
    // (matugen roto: no spamear procesos); finished(false) avisa.
    property int watchdogKills: 0
    property Timer genWatchdog: Timer {
        interval: 120000
        onTriggered: {
            if (root.proc.running) {
                console.warn("[Theme] timeout generando, mato matugen");
                root.watchdogKills += 1;
                if (root.watchdogKills >= 2) {
                    root.hasPending = false;
                    root.pending = "";
                }
                root.proc.running = false;
            }
        }
    }

    // Frame confirmado para el video en curso ("": aun extrayendose).
    // Tras reiniciar, el frame en disco se reconfirma via frameReady sin
    // reescribir nada (el script es idempotente).
    property string confirmedVideo: ""
    property string confirmedFrame: ""

    // Fuente efectiva para matugen. "" = aun no lista (frame en curso; al
    // terminar, frameReady re-invoca la generacion). Se consulta tambien el
    // mapa del servicio (no solo el handler propio) para no quedarse
    // esperando si una entrega de senal se pierde entre recargas.
    function resolveThemeSource(wallpaperPath: string): string {
        if (wallpaperPath === "")
            return "";
        if (!WallpaperService.isVideo(wallpaperPath))
            return wallpaperPath;
        VideoFrameService.ensureFrame(wallpaperPath);
        if (root.confirmedVideo === wallpaperPath && root.confirmedFrame !== "")
            return root.confirmedFrame;
        if (VideoFrameService.confirmed[wallpaperPath] !== undefined)
            return VideoFrameService.frameFor(wallpaperPath);
        return "";
    }

    // Entrada en vuelo (para marcar last* al terminar con éxito).
    property string currentWallpaperReq: ""
    property string currentMode: ""
    property string currentType: ""
    property Process proc: Process {
        onExited: exitCode => {
            root.genWatchdog.stop();
            const ok = exitCode === 0;
            if (ok) {
                root.lastWallpaper = root.currentWallpaperReq;
                root.lastMode = root.currentMode;
                root.lastType = root.currentType;
                root.hasGenerated = true;
                root.watchdogKills = 0;
            }
            root.generationFinished(ok);
            // Solo la última gana: si llegaron más cambios durante el
            // vuelo, se aplica la más reciente (modo/tipo se leen en vivo).
            // Redundante: lo pendiente coincide con lo recién generado.
            if (root.hasPending) {
                const next = root.pending;
                root.hasPending = false;
                root.pending = "";
                if (!(ok && next === root.lastWallpaper && root.matugenMode === root.lastMode
                      && root.matugenType === root.lastType))
                    root.startGenerate(next);
            }
        }
    }

    signal generationStarted
    signal generationFinished(bool success)

    function applyTheme(wallpaperPath: string) {
        root.updateMatugenColors(wallpaperPath);
    }

    // Punto de entrada explícito para shell.qml: aplica el tema actual al
    // arrancar (no-op si aún no hay wallpaper persistido).
    function init() {
        if (root.currentWallpaper !== "")
            root.updateMatugenColors(root.currentWallpaper);
    }

    function updateMatugenColors(wallpaperPath: string) {
        // Los videos generan con su frame ("" = aun extrayendose; al
        // terminar, frameReady re-invoca esto). Desde aqui todo va en
        // espacio resuelto (src): imagen o frame confirmado.
        const src = root.resolveThemeSource(wallpaperPath);
        if (src === "")
            return;
        // Dedup: misma entrada ya generada y nada en vuelo ni en espera.
        if (root.hasGenerated && !proc.running && !root.hasPending && src === root.lastWallpaper && root.matugenMode
                === root.lastMode && root.matugenType === root.lastType)
            return;
        // En vuelo: encola sin matar (ver nota arriba). Si es la misma
        // entrada que vuela o que espera, no hay nada que hacer.
        if (proc.running) {
            if (src === root.currentWallpaperReq && root.matugenMode === root.currentMode && root.matugenType
                    === root.currentType)
                return;
            if (root.hasPending && src === root.pending)
                return;
            root.pending = src;
            root.hasPending = true;
            return;
        }
        root.startGenerate(src);
    }

    function startGenerate(wallpaperPath: string) {
        root.currentWallpaperReq = wallpaperPath;
        root.currentMode = root.matugenMode;
        root.currentType = root.matugenType;
        // Prioridad baja: no roba CPU al compositor durante la transición.
        // Dos pasadas: config.toml (núcleo: terminal, shell, prompt) y apps.toml
        // (apps GTK, Thunar, carpetas...). Si falla la primera no se corre la
        // segunda; el exit code refleja ambas.
        proc.command = ["sh", "-c", "nice -n 15 matugen image \"$1\" --source-color-index 0 -t \"$2\" -m \"$3\" && nice -n 15 matugen -c \"$HOME/.config/matugen/apps.toml\" image \"$1\" --source-color-index 0 -t \"$2\" -m \"$3\"", "matugen-theme", wallpaperPath, root.matugenType, root.matugenMode];
        root.generationStarted();
        proc.running = true;
        root.genWatchdog.restart();
    }

    // QML emitirá automáticamente estos eventos cuando el JsonAdapter actualice los valores subyacentes
    onMatugenModeChanged: root.updateMatugenColors(currentWallpaper)
    onMatugenTypeChanged: root.updateMatugenColors(currentWallpaper)

    Connections {
        function onChanged(newWallpaper: string) {
            root.applyTheme(newWallpaper);
        }

        target: WallpaperService
    }

    Connections {
        // Solo el fondo actual dispara generacion: los frames que pide el
        // menu (miniaturas) no deben regenerar el tema.
        function onFrameReady(videoPath: string, framePath: string) {
            if (videoPath === root.currentWallpaper) {
                root.confirmedVideo = videoPath;
                root.confirmedFrame = framePath;
                root.updateMatugenColors(videoPath);
            }
        }

        target: VideoFrameService
    }
}
