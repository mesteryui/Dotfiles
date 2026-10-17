pragma Singleton

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

// Color representativo por fondo, para el filtro por color del selector.
// - Los colores los calcula `scripts/wallpaper-scan.py` (ImageMagick para
//   imágenes, ffmpeg para vídeos) y quedan cacheados en State: un segundo
//   plano no re-decoda todos los fondos, solo los nuevos o modificados.
// - Este singleton solo orquesta: lanza el escaneo (uno a la vez, con
//   timeout + kill) y lee la caché de forma reactiva vía FileView. La
//   clasificación de tonos vive en el script, no aquí.
// - `tones` debe coincidir con las claves que emite el script y con los
//   swatches de `Panels/Wallpaper/Content/WallpaperFilterBar.qml`.
Singleton {
    id: root

    readonly property list<string> tones: ["red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink",
        "brown", "white", "gray", "black"]

    readonly property string cachePath: Directories.state + "/quickshell/wallpaper-colors.json"
    readonly property string scanScript: Directories.config + "/quickshell/scripts/wallpaper-scan.py"

    // Ruta absoluta -> { tone, hex, luma }.
    property var colors: ({})
    // tone -> nº de fondos, para atenuar los swatches sin resultados.
    property var counts: ({})
    // ready: la caché se leyó (aunque esté vacía o no exista aún).
    property bool ready: false
    property bool scanning: false
    property int entries: 0

    // Escaneo: un solo python a la vez. `command` se fija en ensureScan()
    // (necesita las extensiones del servicio de fondos).
    property Process scanProc: Process {
        onExited: exitCode => {
            root.watchdog.stop();
            root.scanning = false;
            if (exitCode === 0) {
                // La caché ya está escrita: relectura reactiva (el contenido
                // de text() solo se refresca con reload()).
                cacheFile.reload();
            } else {
                console.warn("[WallpaperColor] el escaneo de colores falló (código " + exitCode + ")");
            }
        }
    }

    // Watchdog: decodificar 60 fondos la primera vez tarda, pero no debe
    // quedar un python colgado para siempre (regla de robustez del repo).
    property Timer watchdog: Timer {
        interval: 300000
        onTriggered: {
            if (root.scanProc.running) {
                console.warn("[WallpaperColor] timeout escaneando colores, mato el proceso");
                root.scanProc.running = false;
            }
        }
    }

    function toneFor(path: string): string {
        const entry = root.colors[String(path || "")];
        return entry ? entry.tone : "";
    }

    function hexFor(path: string): string {
        const entry = root.colors[String(path || "")];
        return entry ? entry.hex : "";
    }

    // Lanza el escaneo si no hay otro en vuelo. Barato cuando la caché está
    // vigente: el script solo hace stat y no reescribe si nada cambió, así
    // que abrir el selector no dispara un re-decode.
    function ensureScan(): void {
        if (root.scanning)
            return;
        root.scanning = true;
        root.scanProc.command = ["python3", root.scanScript, "--cache", root.cachePath, "--dir",
                                 WallpaperService.wallpaperDir, "--image-exts",
                                 WallpaperService.extensions.join(","), "--video-exts",
                                 WallpaperService.videoExtensions.join(",")];
        root.scanProc.running = true;
        root.watchdog.restart();
    }

    function readCache(): void {
        let parsed = null;
        try {
            parsed = JSON.parse(cacheFile.text());
        } catch (e) {
            console.warn("[WallpaperColor] caché ilegible: " + e);
        }
        const files = parsed && parsed.files ? parsed.files : ({});
        const tally = {};
        for (const tone of root.tones)
            tally[tone] = 0;
        for (const key in files) {
            const tone = files[key] ? String(files[key].tone || "") : "";
            if (tally[tone] !== undefined)
                tally[tone] += 1;
        }
        root.colors = files;
        root.counts = tally;
        root.entries = Object.keys(files).length;
        root.ready = true;
    }

    FileView {
        id: cacheFile

        path: root.cachePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readCache()
        onLoadFailed: error => {
            // Primera ejecución: aún no hay caché. Se escanea y aparecen los
            // colores al terminar (o se queda vacía si no hay herramientas).
            if (error !== FileViewError.FileNotFound)
                console.warn("[WallpaperColor] no se pudo leer la caché: " + error);
            root.colors = ({});
            root.counts = ({});
            root.entries = 0;
            root.ready = true;
        }
    }
}
