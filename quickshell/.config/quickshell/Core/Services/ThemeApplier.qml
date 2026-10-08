pragma Singleton

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Fuente para matugen: el wallpaper estático persistido.
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
                if (!(ok && next === root.lastWallpaper && root.matugenMode === root.lastMode && root.matugenType === root.lastType))
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
        if (wallpaperPath === "")
            return;
        // Dedup: misma entrada ya generada y nada en vuelo ni en espera.
        if (root.hasGenerated && !proc.running && !root.hasPending && wallpaperPath === root.lastWallpaper && root.matugenMode === root.lastMode && root.matugenType === root.lastType)
            return;
        // En vuelo: encola sin matar (ver nota arriba). Si es la misma
        // entrada que vuela o que espera, no hay nada que hacer.
        if (proc.running) {
            if (wallpaperPath === root.currentWallpaperReq && root.matugenMode === root.currentMode && root.matugenType === root.currentType)
                return;
            if (root.hasPending && wallpaperPath === root.pending)
                return;
            root.pending = wallpaperPath;
            root.hasPending = true;
            return;
        }
        root.startGenerate(wallpaperPath);
    }

    function startGenerate(wallpaperPath: string) {
        root.currentWallpaperReq = wallpaperPath;
        root.currentMode = root.matugenMode;
        root.currentType = root.matugenType;
        // Prioridad baja: no roba CPU al compositor durante la transición.
        proc.command = ["nice", "-n", "15", "matugen", "image", wallpaperPath, "--source-color-index", "0", "-t", root.matugenType, "-m", root.matugenMode];
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
}
