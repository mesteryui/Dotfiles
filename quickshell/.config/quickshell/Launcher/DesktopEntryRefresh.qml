// --- DesktopEntryRefresh ---
// Refresca el índice de .desktop AL ABRIR el launcher, y solo si cambió.
//
// Por qué no watchers permanentes:
//   Quickshell 0.3.x ya vigila los DIRECTORIOS XDG (DesktopEntryMonitor).
//   Eso cubre alta/baja/renombrado y guardados atómicos (vim, sed -i,
//   rename), pero no ediciones in place: cambiar el contenido no toca el
//   mtime del directorio, así que DesktopEntries no rescanea. Un FileView
//   por .desktop sí lo detecta, pero son ~200 QFileSystemWatcher (y sus
//   inotify fds) permanentes para algo que solo importa al abrir el menú.
//   Walker y launchers similares comprueban al abrir, no en reposo.
//
// Estrategia (coste casi cero con el launcher cerrado):
//   1. En onOpened se lanza un `find` que devuelve path+mtime+ctime+
//      tamaño de cada .desktop (solo stat, no lee contenido). Es asíncrono.
//   2. Primera apertura: se guarda la huella. Si DesktopEntries ya tenía
//      datos de un scan anterior (otro consumidor), se fuerza un rescan
//      para no arrancar con datos viejos.
//   3. Aperturas siguientes: si la huella cambió, se "toca" un marcador
//      no-.desktop en ~/.local/share/applications. Ese alta/baja del
//      directorio dispara el directoryChanged de Quickshell y su rescan
//      completo; si no cambió, no se hace nada.
//   4. AppLauncher escucha DesktopEntries.applicationsChanged (se emite al
//      terminar cualquier rescan) y rehace los snapshots de sortedBase.
//
// La huella es el propio texto de `find` (~20 KB); no se parsea ni se
// guarda en disco. El marcador se crea y se borra en el mismo proceso.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Mismo cálculo que DesktopEntryManager::desktopPaths().
    readonly property string home: Quickshell.env("HOME")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")
    readonly property string dataDirsRaw: Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share"
    readonly property var dataDirs: dataDirsRaw.split(":").filter(d => d !== "")
    readonly property var appDirs: {
        const dirs = [dataHome + "/applications"].concat(dataDirs.map(d => d + "/applications"));
        // XDG_DATA_HOME puede estar también en XDG_DATA_DIRS: sin duplicar
        // trabajo por el mismo directorio.
        return dirs.filter((d, i) => dirs.indexOf(d) === i);
    }
    // Nuestro único nudge: el dir de usuario siempre es escribible.
    readonly property string triggerDir: appDirs[0]
    readonly property string rescanMarker: triggerDir + "/.quickshell-desktop-rescan"
    readonly property string nudgeScript: 'mkdir -p "$1" && : > "$2" && rm -f "$2"'
    // sort hace la huella estable entre ejecuciones (find no garantiza orden).
    readonly property string listScript: "find \"$@\" -type f -name \"*.desktop\" "
                                         + "-printf '%p\\t%T@\\t%C@\\t%s\\n' 2>/dev/null | sort"

    // Huella de la última comprobación (path + mtime + ctime + tamaño).
    property string baseline: ""
    property bool initialized: false
    // DesktopEntries ya existía antes de esta primera apertura: su scan
    // pudo quedar viejo y hay que forzar uno nuevo.
    property bool firstHadEntries: false
    // Si se abre/cierra muy rápido, no se solapa otra comprobación.
    property bool pending: false

    function check() {
        if (scanProc.running) {
            root.pending = true;
            return;
        }
        if (!root.initialized)
            root.firstHadEntries = DesktopEntries.applications.values.length > 0;
        scanProc.running = true;
    }

    function nudge() {
        Quickshell.execDetached(["bash", "-c", root.nudgeScript, "qs-desktop-rescan", root.triggerDir,
                                 root.rescanMarker]);
    }

    Process {
        id: scanProc

        // find recibe los dirs como argumentos ($@): soporta espacios y
        // no interpola rutas dentro del shell.
        command: ["bash", "-c", root.listScript, "qs-desktop-list"].concat(root.appDirs)

        stdout: StdioCollector {
            onStreamFinished: {
                const snapshot = String(text);
                if (!root.initialized) {
                    root.initialized = true;
                    root.baseline = snapshot;
                    // No se fuerza rescan en la primera apertura normal: el
                    // scan inicial de DesktopEntries acaba de leer el disco.
                    if (root.firstHadEntries)
                        root.nudge();
                } else if (snapshot !== root.baseline) {
                    root.baseline = snapshot;
                    root.nudge();
                }
                if (root.pending) {
                    root.pending = false;
                    // Dejar que Process termine de asentarse antes de relanzar.
                    Qt.callLater(root.check);
                }
            }
        }
    }
}
