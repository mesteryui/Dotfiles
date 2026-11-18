pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Propiedades que consume UpdateCounter
    property alias updateCount: persistent.updateCount
    property bool checking: false
    property bool updating: false
    property bool failed: false
    // Evita repetir el chequeo inicial (timer + al recuperar la red).
    property bool startupCheckDone: false
    // Si `checkupdates` no existe (no-Arch), se detecta una vez (exit 127)
    // y se deja de spawnear en cada ciclo: sin esto cada poll lanzaba un
    // proceso condenado al fallo.
    property bool checkerMissing: false
    // Modo del chequeo en curso: true = con descarga de BDs de repos
    // (lento, red), false = conteo local con --nosync (<1s, sin red).
    // Decide el intervalo del watchdog y si un timeout es fatal.
    property bool syncCheck: false
    // true cuando una sync ha terminado bien en esta sesión: las BDs de
    // /tmp/checkup-db-$UID están sembradas y los conteos --nosync ya son
    // válidos (sin esto, tras reiniciar, un poll daría un 0 falso).
    property bool dbSynced: false

    property ListModel packagesToUpdate: ListModel {}

    // Watchdog: el conteo --nosync es local (<1s): 2 min de gracia sobran.
    // La sync descarga las BDs de todos los repos (~15 MB con cachyos +
    // chaotic-aur): 15 min para tolerar espejos lentos o wifi degradado.
    // Un timeout en --nosync sí es un fallo real (se marca failed); en la
    // sync no (el conteo anterior sigue siendo válido).
    property Timer countWatchdog: Timer {
        interval: root.syncCheck ? 900000 : 120000
        onTriggered: {
            if (countUpdates.running) {
                countUpdates.running = false;
                if (root.syncCheck) {
                    // Red/espejo colgado a mitad de descarga: no es un fallo
                    // del contador (el conteo anterior sigue siendo válido).
                    // Silencio: el syncTimer reintenta en su próximo ciclo.
                    console.info("[Updates] sync de BDs lenta, corto y reintento luego");
                } else {
                    console.warn("[Updates] timeout chequeando, mato checkupdates");
                    root.failed = true;
                }
            }
        }
    }

    // Lanza un chequeo. sync=false: conteo local contra las BDs ya
    // descargadas (--nosync, instantáneo y sin red: no puede colgarse).
    // sync=true: chequeo completo con descarga de BDs (lento; watchdog
    // largo y timeout no fatal).
    function startCheck(sync) {
        if (root.checkerMissing)
            return;
        root.syncCheck = sync;
        countUpdates.command = sync ? ["checkupdates"] : ["checkupdates", "--nosync"];
        countUpdates.running = true;
    }

    function tryStartupCheck() {
        if (root.startupCheckDone || root.checkerMissing)
            return;
        if (!NetworkService?.hasInternet)
            return;
        // Solo inicial y sin colisionar: si ya hay un chequeo o una
        // actualización en curso, no se duplica ahora pero tampoco se da
        // por cumplido el chequeo de arranque: se reintentará en el siguiente
        // tick del startupTimer (que sigue armado) hasta que se ejecute.
        if (countUpdates.running || root.checking || root.updating) {
            startupTimer.restart();
            return;
        }
        root.startupCheckDone = true;
        startupTimer.stop();
        root.startCheck(true);
    }

    function checkNow() {
        root.startCheck(true);
    }

    function update() {
        // Sin comando no hay nada que lanzar: evita abrir un terminal
        // vacío si la config quedó en blanco.
        if (root.updateArgs().length === 0) {
            console.warn("[Updates] comando vacío, no se lanza actualización");
            return;
        }
        updateProcess.running = true;
    }

    // Parseo del comando configurable (Settings → updates.command)
    // respetando comillas simples/dobles y `\` de escape, en vez de un
    // split(" ") ciego que rompía args con espacios y cambiaba el
    // significado del comando.
    function updateArgs() {
        const out = [];
        let cur = "";
        let quote = "";
        let escaped = false;
        let has = false;
        const src = String(ConfigService.configs.updates.command ?? "");
        for (let i = 0; i < src.length; i++) {
            const c = src[i];
            if (escaped) {
                cur += c;
                escaped = false;
                has = true;
                continue;
            }
            if (c === "\\" && quote !== "'") {
                escaped = true;
                continue;
            }
            if (quote !== "") {
                if (c === quote)
                    quote = "";
                else
                    cur += c;
                has = true;
                continue;
            }
            if (c === "'" || c === '"') {
                quote = c;
                has = true;
                continue;
            }
            if (c === " " || c === "\t" || c === "\n") {
                if (has) {
                    out.push(cur);
                    cur = "";
                    has = false;
                }
                continue;
            }
            cur += c;
            has = true;
        }
        if (escaped)
            cur += "\\";
        if (has)
            out.push(cur);
        return out;
    }

    PersistentProperties {
        id: persistent

        reloadableId: "updatePersistence"

        property int updateCount: 0
    }

    Timer {
        id: pollTimer

        // Sujeto a la config: mínimo 1 min, y se reinicia si countTime cambia.
        interval: Math.max(1, ConfigService.configs.updates.countTime) * 60000
        running: true
        repeat: true
        // Conteo barato (--nosync): compara el local con las BDs ya
        // descargadas. Sin internet la igualda no cambia, así que se salta.
        // Tampoco pisa un chequeo o actualización ya en curso, ni corre
        // antes de que la primera sync haya sembrado las BDs (daría 0 falso).
        onTriggered: {
            if (root.checkerMissing)
                return;
            if (!(NetworkService?.hasInternet ?? true))
                return;
            if (countUpdates.running || root.checking || root.updating)
                return;
            if (!root.dbSynced)
                return;
            root.startCheck(false);
        }
    }

    // Descarga de BDs desacoplada del conteo: es la parte lenta y la única
    // que toca la red (era la causante del timeout del watchdog con espejos
    // lentos). Cadencia propia: mínimo 60 min aunque countTime sea menor.
    // El arranque (startupTimer) y la recuperación de red hacen la primera
    // sync mucho antes que este primer tick.
    Timer {
        id: syncTimer

        interval: Math.max(60, ConfigService.configs.updates.countTime) * 60000
        running: true
        repeat: true
        onTriggered: {
            if (root.checkerMissing)
                return;
            if (!(NetworkService?.hasInternet ?? true))
                return;
            if (countUpdates.running || root.checking || root.updating)
                return;
            root.startCheck(true);
        }
    }

    // Chequeo único al arrancar si hay internet: un solo disparo
    // diferido (60s, fuera del pico de inicialización) para no pisar el
    // arranque, más un reintento al recuperar la red solo si el inicial
    // no llegó a ejecutarse.
    Timer {
        id: startupTimer

        interval: 60000
        running: true
        repeat: false
        onTriggered: root.tryStartupCheck()
    }

    Connections {
        target: ConfigService.configs.updates

        function onCountTimeChanged() {
            pollTimer.restart();
            syncTimer.restart();
        }
    }

    Connections {
        target: NetworkService

        function onHasInternetChanged() {
            if (!root.startupCheckDone)
                root.tryStartupCheck();
        }
    }

    Process {
        id: countUpdates

        // El comando lo fija startCheck() en cada arranque: sync completo
        // o conteo local --nosync. El valor inicial (sync) es el del primer
        // chequeo de arranque.
        command: ["checkupdates"]

        onRunningChanged: {
            if (running) {
                root.checking = true;
                root.failed = false;
                root.packagesToUpdate.clear();
                root.countWatchdog.restart();
            } else {
                root.checking = false;
                root.countWatchdog.stop();
            }
        }

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "")
                    return;

                // formato: "nombre ver_antigua -> ver_nueva"
                const parts = line.split(" ");
                if (parts.length >= 4) {
                    root.packagesToUpdate.append({
                                                     name: parts[0],
                                                     oldVersion: parts[1],
                                                     newVersion: parts[3]
                                                 });
                }
            }
        }

        // qmllint disable signal-handler-parameters
        onExited: exitCode => {
            if (exitCode === 127) {
                // Binario ausente (p. ej. no-Arch): no reintentar en cada
                // ciclo. Se marca failed una vez para que el icono avise.
                root.checkerMissing = true;
                root.failed = true;
                return;
            }
            if (exitCode === 0 || exitCode === 2) {
                root.updateCount = root.packagesToUpdate.count;
                root.failed = false;
                // Las BDs quedaron sembradas: los polls --nosync ya son válidos.
                if (root.syncCheck)
                    root.dbSynced = true;
            } else {
                root.failed = true;
            }
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: updateProcess
        // El comando de la config se parsea con updateArgs() (respeta
        // comillas) y se expande como argv, sin pasar por shell.

        command: ["xdg-terminal-exec", "--app-id=local.floating", "-e", ...root.updateArgs()]

        onRunningChanged: {
            root.updating = running;
        }

        // qmllint disable signal-handler-parameters
        onExited: exitCode => {
            // Tras actualizar, la sync refresca las BDs y rellena el conteo
            // con datos frescos (el local se lee vivo vía symlink).
            if (!countUpdates.running)
                root.startCheck(true);
        }
        // qmllint enable signal-handler-parameters
    }

    IpcHandler {
        target: "update"

        function updateSystem() {
            root.update();
        }
    }
}
