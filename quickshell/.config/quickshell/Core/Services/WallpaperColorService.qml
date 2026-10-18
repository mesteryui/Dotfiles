pragma Singleton

import qs.Core.Modules
import QtQuick
import Quickshell
import Quickshell.Io

// Color representativo por fondo, para el filtro por color del selector.
//
// Réplica del sistema de Ryoku
// (ryoku/shell/quickshell/wallpaper/Singletons/Colors.qml): cada fondo se
// reduce a su color medio y se lee su HSL; el par (hue, saturación) clasifica
// el fondo en uno de 12 grupos de hue o en un cajón neutro (casi escala de
// grises). El filtro del selector trabaja con esos grupos.
//
// Los colores los calcula `scripts/wallpaper-scan.py` (ImageMagick para
// imágenes, ffmpeg para vídeos) y quedan cacheados en State: un segundo plano
// no re-decoda todos los fondos, solo los nuevos o modificados. Este singleton
// solo orquesta: lanza el escaneo (uno a la vez, con timeout + kill), lee la
// caché de forma reactiva vía FileView y agrupa hue/sat (bucket).
Singleton {
    id: root

    // ── Agrupación de color ─────────────────────────────────────────────
    // Cajón neutro (near-greyscale). Igual que Ryoku.
    readonly property int neutral: 99

    // hue en grados (0-360), sat en porcentaje (0-100) -> id de grupo.
    function bucket(hue: real, sat: real): int {
        if (sat < 10)
            return root.neutral;
        if (hue >= 340 || hue < 25)
            return 0;
        return Math.floor((hue - 25) / 30) + 1;
    }

    // Relleno del swatch de un grupo: arcoíris uniforme; gris para el neutro.
    function swatch(id: int): color {
        if (id === root.neutral)
            return Qt.hsla(0, 0, 0.52, 1);
        return Qt.hsla(id / 12, 0.62, 0.52, 1);
    }

    // Tinta legible (check) sobre el swatch de un grupo.
    function swatchInk(id: int): color {
        const c = root.swatch(id);
        const luma = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return luma > 0.55 ? Qt.rgba(0.1, 0.1, 0.1, 1) : Qt.rgba(1, 1, 1, 1);
    }

    // Grupos en orden arcoíris, neutro al final.
    readonly property var order: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 99]

    readonly property var names: ({
                                      0: "Red",
                                      1: "Orange",
                                      2: "Amber",
                                      3: "Lime",
                                      4: "Green",
                                      5: "Teal",
                                      6: "Cyan",
                                      7: "Sky",
                                      8: "Blue",
                                      9: "Violet",
                                      10: "Magenta",
                                      11: "Pink",
                                      99: "Neutral"
                                  })

    // Claves i18n por grupo (`wallpaper.color.<key>`), alineadas con `names`.
    readonly property var keys: ({
                                     0: "red",
                                     1: "orange",
                                     2: "amber",
                                     3: "lime",
                                     4: "green",
                                     5: "teal",
                                     6: "cyan",
                                     7: "sky",
                                     8: "blue",
                                     9: "violet",
                                     10: "magenta",
                                     11: "pink",
                                     99: "neutral"
                                 })

    // ── Datos ───────────────────────────────────────────────────────────
    readonly property string cachePath: Directories.state + "/quickshell/wallpaper-colors.json"
    readonly property string scanScript: Directories.config + "/quickshell/scripts/wallpaper-scan.py"

    // Ruta absoluta -> { hue, sat, group }.
    property var colors: ({})
    // group -> nº de fondos, para la tira de color (solo grupos con fondos).
    property var counts: ({})
    // ready: la caché se leyó (aunque esté vacía o no exista aún).
    property bool ready: false
    property bool scanning: false
    property int entries: 0

    // Grupos con al menos un fondo, en orden arcoíris (los que muestra la tira).
    readonly property var presentGroups: {
        const out = [];
        for (const g of root.order) {
            if ((root.counts[g] ?? 0) > 0)
                out.push(g);
        }
        return out;
    }

    // id de grupo del fondo en `path`, o -1 si aún no tiene color.
    function groupFor(path: string): int {
        const entry = root.colors[String(path || "")];
        return entry ? entry.group : -1;
    }

    // Saturación (%) del fondo, para ordenar dentro de un grupo. 0 si no hay.
    function satFor(path: string): real {
        const entry = root.colors[String(path || "")];
        return entry ? entry.sat : 0;
    }

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
        const dict = {};
        const tally = {};
        for (const g of root.order)
            tally[g] = 0;
        for (const key in files) {
            const raw = files[key] || {};
            const hue = Number(raw.hue) || 0;
            const sat = Number(raw.sat) || 0;
            const group = root.bucket(hue, sat);
            dict[key] = {
                "hue": hue,
                "sat": sat,
                "group": group
            };
            tally[group] = (tally[group] ?? 0) + 1;
        }
        root.colors = dict;
        root.counts = tally;
        root.entries = Object.keys(dict).length;
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
