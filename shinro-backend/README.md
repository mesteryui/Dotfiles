# shinro-backend

Backend ligero en Go para la shell **shinro** (Quickshell). Expone un único
socket Unix llamado `shinro` por el que la shell obtiene recursos del sistema
y clima, de forma independiente y modular.

## Estructura

```
shinro-backend/
├── cmd/shinro-backend/main.go         # punto de entrada
├── cmd/shinro-shell/main.go           # CLI para hablar con el socket
├── Makefile                          # build (fija GOAMD64=v3)
├── internal/safe                      # recuperación de panics en goroutines
├── internal/system                    # RAM, CPU, swap, uptime, temperatura, batería (/proc, /sys)
├── internal/weather                   # clima (Open-Meteo, AQI, avisos MeteoAlarm)
├── internal/geo                       # tipos de ubicación compartidos (solo modo manual)
├── internal/connectivity              # eventos de red vía NetworkManager D-Bus
├── internal/clipboard                 # portapapeles Wayland nativo (data-control) + historial
├── internal/files                     # búsqueda difusa y cancelable de archivos (inotify)
├── internal/socket                    # servidor Unix socket, protocolo JSON
├── vendor/                            # godbus vendorizado: build sin red
├── go.mod
├── go.sum
└── README.md
```

Cada paquete es independiente: `system` no conoce a `weather`, y viceversa.
Se comunican solo a través del servidor del socket.

**El backend es Linux-only** (y no hay intención de que lo sea de otra cosa):
lee `/proc` y `/sys`, habla D-Bus con NetworkManager, usa `inotify` para
detectar cambios en el árbol de ficheros y habla el protocolo Wayland
`data-control` directamente sobre el socket del compositor. No hay variants
para otras plataformas ni cross-compilation.

## Robustez del daemon

El backend es un proceso de larga vida (días) que hace de todo a la vez. Las
decisiones de diseño que lo mantienen en pie:

### Ningún panic tumba el daemon

En Go, un panic sin recuperar en *cualquier* goroutine mata el proceso
entero. Todo el arranque de goroutines pasa por `internal/safe`:

```go
safe.Go("clima.forecast", func() { ... })            // el panic se registra
safe.Do("clima.forecast", func() error { ... })       // el panic es un error
safe.DoValue("clima.aqi", func() (int, error) { ... })
safe.Guard("portapapeles.watch", func() { ... })      // el bucle reintenta
```

El panic se registra con su stack (nivel `error`) y la ejecución continúa: el
fallo queda aislado al módulo que lo provocó. El módulo `weather` convierte
un fallo del proveedor en un error para el cliente, no en la muerte del
proceso.

### Goroutines con ciclo de vida definido

- Los pumps de los módulos se registran en un `WaitGroup` **antes** de
  arrancar la goroutine, y el apagado los espera (con un tiempo límite).
- Durante el apagado no se arrancan pumps nuevos, para no usar el `WaitGroup`
  mientras otro `Wait` está en curso.
- El vuelo compartido de `weather` (dos clientes pidiendo el mismo parte a la
  vez) cierra su canal de forma garantizada y borra su entrada del mapa: los
  seguidores nunca se quedan colgados y el mapa no crece sin control.
- El listener de señales D-Bus de NetworkManager termina al cerrar el
  monitor, en vez de esperar indefinidamente.
- Las búsquedas de archivos son cancelables: una query nueva aborta la
  anterior y la desconexión del cliente aborta la que quedara, así que no se
  acumulan recorridos del disco.
- El `acceptLoop` hace una pausa ante un error transitorio del listener, para
  no entrar en modo *busy loop* quemando CPU.

### Sin polling a ciegas

- **Red**: se escuchan los eventos de NetworkManager por D-Bus
  (`StateChanged` / `PropertiesChanged`). La verificación HTTP es un
  *heartbeat* de respaldo y se hace en segundo plano, para que una comprobación
  lenta no retrace la reacción a los eventos.
- **Portapapeles**: se habla el protocolo Wayland `data-control` directamente
  sobre el socket del compositor. Los cambios llegan como eventos, sin polling
  ni procesos `wl-copy`/`wl-paste`, y el backend es el dueño de la selección.
- **Sistema**: todo se lee de pseudo-archivos del kernel (`/proc/stat`,
  `/proc/meminfo`, `/sys/class/thermal`, `/sys/class/power_supply`): leer unos
  pocos KiB cuesta mucho menos que lanzar procesos o consultar APIs.
- **Ficheros**: los cambios en el árbol de directorios se detectan con
  `inotify` (eventos del kernel), no con polling.

### Recuperación de la red

Cuando NetworkManager avisa de que vuelve la conexión, el backend dispara un
refresco inmediato del clima (y de cualquier otro módulo que dependa de
Internet) sin esperar al siguiente tick, y el shell no necesita saber nada de
la capa de red: recibe el parte nuevo por el mismo socket de siempre.

Si no hay red, el clima se sirve desde la caché del último parte válido,
marcado con `"_offline": true`.

## Protocolo (socket Unix)

El socket se crea en `/run/user/$UID/shinro` (o en `$XDG_RUNTIME_DIR/shinro`,
que es la misma ruta en una sesión systemd de usuario) con permisos `0600`.
Los mensajes son JSON, una línea por mensaje.

### Handshake inicial (`hello`)

La shell envía al conectar (usando `Quickshell.Io.Socket`):

```json
{
  "type": "hello",
  "location": {
    "mode": "manual",   // o "auto" para Geoclue
    "city": "Madrid"    // ciudad fija (manual) o de respaldo (auto)
  },
  "intervals": {
    "system": 5,   // segundos entre actualizaciones de recursos
    "weather": 600 // segundos entre actualizaciones de clima
  }
}
```

El servidor responde:

```json
{"type":"hello","ok":true,"mode":"manual","city":"Madrid"}
```

### Actualizaciones periódicas (`update`)

El servidor empuja automáticamente sin que la shell tenga que pedir:

```json
{"type":"update","module":"system","data":{"ram_percent":34,"cpu_percent":12,"swap_percent":4,"uptime_seconds":12000,"temperature_c":55,"battery_percent":78,"battery_status":"Discharging","battery_charging":false,"battery_time_to_empty_min":214}}
```

Los campos de batería vienen de `/sys/class/power_supply`; en equipos sin
batería, `battery_percent` vale `-1` y `battery_status` está vacío.

```json
{"type":"update","module":"weather","data":{
  "current":{"temperature_2m":19.5,"relative_humidity_2m":66,"apparent_temperature":17.3,
             "is_day":0,"precipitation":0,"weather_code":3,"surface_pressure":996.1,
             "wind_speed_10m":21.2,"wind_direction_10m":138},
  "daily":{"time":["2026-11-08","2026-11-09","2026-11-10","2026-11-11"],
           "weather_code":[3,61,3,2],"temperature_2m_max":[22.2,19.7,17.8,19.7],
           "temperature_2m_min":[17.0,16.5,15.2,14.8],
           "sunrise":["2026-11-08T08:16"],"sunset":["2026-11-08T18:20"],
           "uv_index_max":[2.4],"precipitation_probability_max":[65,95,35,10]},
  "hourly":{"time":["2026-11-08T00:00"],"temperature_2m":[17.0],
            "precipitation_probability":[0],"weather_code":[3],"visibility":[39900],
            "is_day":[0]},
  "_cityLabel":"Vigo, Comunidad Autónoma de Galicia",
  "_aqi":20,
  "_alerts":[{"level":2,"event":"Aviso de costeros de nivel amarillo",
              "area":"Costa - Miño de Pontevedra",
              "onset":"2026-11-08T21:00:00+01:00",
              "expires":"2026-11-08T23:59:59+01:00",
              "description":"Viento del Sur de 50 a 61 km/h (fuerza 7)."}]
}}
```

El payload de `weather` replica la forma de Open-Meteo (`current`/`daily`/`hourly`)
para que la shell reutilice su mismo formateo, y añade `_cityLabel`, `_aqi`
(calidad del aire europea) y `_alerts` (avisos MeteoAlarm ya filtrados por zona).
El handshake admite además `"lang": "es"` para elegir el idioma de los avisos.

### Cachés y tiempos del clima

El parte meteorológico se componía de cuatro peticiones de red, y una de
ellas (el feed de avisos de MeteoAlarm, **2,7 MB**) tardaba varios segundos y
bloqueaba el envío entero. Con un refresco de 60 s, eso son 5 s de espera en
cada actualización.

Ahora:

| Dato | Caché | Por qué |
|------|-------|---------|
| Coordenadas | 24 h | las coordenadas de una ciudad no cambian |
| Previsión | 5 min | Open-Meteo actualiza cada ~15 min |
| Calidad del aire | 15 min | cambia cada media hora como mucho |
| Avisos (MeteoAlarm) | 15 min | **se descarga en segundo plano**: el refresco nunca espera a los 2,7 MB |

Cuando el feed de avisos llega, se avisa a los clientes suscritos para que
refresquen el parte y muestren los avisos sin esperar al siguiente tick.

Además, el módulo `ping` informa del **desglose** del último parte, que dice
en qué se va el tiempo:

```
desglose de weather: geocode 0.0 ms, forecast 0.0 ms, aqi 0.0 ms, alerts 0.4 ms, total 0.4 ms
```

Cuando la conectividad se recupera, el módulo `weather` **descarta sus
cachés**: si el daemon estuvo un rato sin red, lo cacheado puede tener horas
y hay que pedirlo todo otra vez.

### Consulta puntual (`get`)

```json
{"type":"get","module":"system"}
```
o
```json
{"type":"get","module":"weather"}
```

### Health check (`ping`)

El módulo `ping` comprueba que el backend responde **y devuelve su estado de
salud**: el estado de cada módulo, los datos del daemon y una lista de
problemas y de cosas que se podrían mejorar.

```json
{"type":"get","module":"ping"}
```

```json
{"type":"update","module":"ping","data":{
  "ok":"true",
  "status":"degraded",
  "uptime_seconds":48213.4,
  "goroutines":37,
  "memory_mb":23.8,
  "clients":2,
  "connectivity":"online",
  "problems":["weather: último error hace 42s: error leyendo weather: dial tcp: i/o timeout"],
  "suggestions":["weather tarda 3200 ms de media: es el cuello de botella del refresco"],
  "modules":[
    {"name":"system","status":"ok","subscribed":true,"subscribers":2,"interval":5,
     "sends":9642,"errors":0,"last_send_ms_ago":3,"last_duration_ms":1.9,"avg_duration_ms":1.87},
    {"name":"weather","status":"error","subscribed":true,"subscribers":1,"interval":600,
     "sends":12,"errors":3,"last_send_ms_ago":42000,"last_duration_ms":8012,"avg_duration_ms":3200,
     "last_error":"error leyendo weather: dial tcp: i/o timeout","last_error_ms_ago":42000}
  ]
}}
```

Campos de cada módulo:

| Campo | Significado |
|-------|-------------|
| `status` | `ok` (la última operación fue bien), `error` (falló) o `idle` (todavía no ha hecho nada) |
| `subscribed` | si el cliente que pregunta está suscrito a ese módulo |
| `subscribers` | cuántos clientes están suscritos en total |
| `interval` | intervalo periódico más corto entre los suscritos (0 = el módulo solo trabaja bajo demanda) |
| `sends` / `errors` | contadores de envíos correctos y fallidos |
| `last_send_ms_ago` | milisegundos desde el último envío correcto |
| `last_duration_ms` / `avg_duration_ms` | cuánto tarda el módulo en responder: **el dato que dice cuál es el cuello de botella** |
| `last_error` | mensaje del último fallo |
| `timings` | desglose del tiempo por sub-petición (solo el clima) |

Y del daemon: `uptime_seconds`, `goroutines`, `memory_mb`, `clients` y
`connectivity`.

### Tendencia: cómo se ve una fuga

`goroutines_delta_5m` y `memory_delta_5m` son las **tendencias**: cuántas
goroutines y cuántos MB han creescido en los últimos 5 minutos. El daemon
muestrea su estado cada 30 s y guarda las últimas 2 horas de mediciones.

Importante: la comparación **no** se hace contra el arranque, sino contra
hace 5 minutos. Comparar contra el arranque no serviría: el daemon arranca
módulos a medida que llegan clientes (el watcher de ficheros, el de
portapapeles), así que al principio el número siempre "crece" y parecería una
fuga que no existe. Con la tendencia, un arranque se estabiliza y solo se ve
lo que sigue creciendo.

Si el consumo crece de forma sostenida, el daemon lo deja en el log (como
mucho una vez cada 5 minutos):

```
INFO salud del daemon goroutines_5m=14 memoria_mb_5m=8.2
```

### Qué se reporta como problema

El informe distingue **problemas** (algo está roto o atascado ahora mismo) de
**cosas a mejorar** (nada está roto, pero el dato apunta a una mejora):

- **Problema**: un módulo cuyo último intento falló (con el mensaje y cuándo),
  o un módulo **periódico** suscrito que lleva más de 3 intervalos sin
  enviar (el pump está muerto o colgado).
- **Cosas a mejorar**: el módulo que más tarda, y un consumo anómalo de
  goroutines o memoria (medido sobre la tendencia, no sobre el total).

Lo que **no** se reporta: que un módulo no tenga clientes suscritos. No es un
problema: los módulos bajo demanda (`files`, `clipboard`) solo trabajan cuando
hace falta, y un módulo periódico sin suscriptores simplemente no está
pumping. Reportarlo sería ruido que taparía los problemas de verdad.

En la CLI, `shinro-shell ping` imprime un resumen legible (estado, tabla de
módulos, problemas y cosas a mejorar) y `shinro-shell ping --json` el informe
en crudo:

```
$ shinro-shell ping
estado: degraded   Conectividad: online
uptime: 13 h 24 min   clientes: 2   goroutines: 37   memoria: 23.8 MB

Módulo      Estado   Suscr.  Envíos  Errores  Último envío  Duración media
system      ok       2        9642    0        3 ms          1.87 ms
weather     error    1        12      3        42 s          3200.00 ms
clipboard   ok       1        87      0        120 ms        0.40 ms

Problemas:
  - weather: último error hace 42 s: error leyendo weather: dial tcp: i/o timeout

Cosas a mejorar:
  - weather tarda 3200 ms de media: es el cuello de botella del refresco
```

### Portapapeles (`clipboard`)

Exposes el historial del portapapeles Wayland (historial persistente,
deduplicación por hash, thumbnails, starred, auto-prune semanal). El cliente
se suscribe enviando `"intervals": {"clipboard": 0}` (o mayor) en el `hello`;
los cambios se empujan al instante vía `SetBroadcast` sin pump periódico.

Acciones mediante `{"type":"get","module":"clipboard","action":...}`:

- `list` — devuelve el historial completo.
- `copy-text` (`text`) / `copy-image` (`path`) — copia al portapapeles y al historial.
- `paste` — devuelve el contenido actual.
- `delete` (`id`) / `clear` — borra entradas.
- `star` (`id`, `starred`) — marca/desmarca starred.
- `stats` — resumen de almacenamiento.
- `get-text` (`id`) — contenido completo (texto) o preview (imagen).
- `recopy` (`id`) — vuelve a poner en el portapapeles y promueve al frente.
- `watch` (`enable`) — activa/desactiva el watch de cambios externos.

### Archivos (`files`)

Búsqueda difusa y concurrente de archivos en `$HOME` (sin fd ni find) mediante
`{"type":"get","module":"files","action":"search","query":"...","limit":20}`.
Devuelve `query` y `results` con `path`, `name`, `size`, `is_dir`, `mime`,
`kind`. Los resultados se cachean para búsquedas progresivas letra a letra.

**Se actualiza solo cuando cambian los ficheros.** El backend vigila el árbol
de directorios con `inotify` (eventos, no polling) y:

- Al crearse, borrarse o moverse un fichero, la caché se invalida al momento:
  la siguiente búsqueda recalcula y devuelve el estado real del disco.
- La última búsqueda de cada cliente se reejecuta sola y el resultado
  actualizado se le empuja por el socket, sin que la UI tenga que pedirlo
  (igual que el módulo de portapapeles).

Para que el refresco no se dispare con cada cambio del sistema, los eventos se
agrupan (debounce de 500 ms) y hay un intervalo mínimo de 3 s entre refrescos
del mismo cliente. Además, solo se vigilan los directorios que las búsquedas
recorren (los no ocultos, hasta la misma profundidad máxima), con un tope de
4096: lo que el buscador ve y lo que el vigilante cubren coinciden.

Si `inotify` no estuviera disponible, la caché tiene además un TTL de 20 s
que garantiza que los resultados no se quedan obsoletos indefinidamente.

> Nota: `results` es siempre un array (aunque esté vacío), nunca `null`; el
> cliente lo usa para decidir si la lista está vacía o sin respuesta.

## Ubicación

El backend **no obtiene la ubicación por su cuenta**. La resuelve la shell
(Quickshell, con su `PositionSource`) y se la envía en el mensaje de `hello`:

```json
{"type": "hello", "location": {"mode": "manual", "city": "Vigo, ES"}}
```

El backend usa esa ciudad para el clima. El paquete `internal/geo` solo
define el vocabulario común (`Mode`, `Location`); no hay proveedor de
geolocalización ni conexión a Geoclue: la ubicación automática es
responsabilidad del cliente.

Si la ciudad está vacía y no hay coordenadas, el clima devuelve un error
explícito (`sin ubicación válida para clima`).

## Cómo compilar

El build es **hermético**: la única dependencia externa
(`github.com/godbus/dbus/v5`) está vendorizada en `vendor/`, así que no hace
falta red ni caché de módulos.

Hay un `Makefile` que fija el nivel de microarquitectura (ver más abajo):

```bash
cd /home/oscar/.dotfiles/shinro-backend
make            # compila shinro-backend y shinro-shell
make check      # vet + tests con detector de carreras + build
```

### GOAMD64: por qué está fijado

**Go 1.27.4 usa `GOAMD64=v4` por defecto**, y el nivel v4 exige **AVX-512**.
Los binarios así compilados no arrancan en CPUs anteriores a AVX-512 (AMD
Zen 3, Intel anteriores a Sapphire Rapids…), y fallan con:

```
This program can only be run on AMD64 processors with v4 microarchitecture support.
```

El `Makefile` fija `GOAMD64=v3`, el nivel de las CPUs actuales (Haswell en
adelante, Zen 1 en adelante): da el rendimiento de AVX2/BMI2 sin exigir
AVX-512. Para otros casos:

```bash
make GOAMD64=v2   # máxima compatibilidad (cualquier CPU de los últimos 15 años)
make GOAMD64=v1   # binarios universales, sin instrucciones extra
```

Esto también afecta al **toolchain**: el paquete de Go de Arch 1.27.4 viene
compilado con v4 y no arranca en CPUs sin AVX-512 (el 1.27.3 usaba v3 y
funcionaba). Si `go version` falla con ese mensaje, o se baja de versión el
paquete o se usa el toolchain oficial de [go.dev](https://go.dev/dl/), que
está compilado para v1 y funciona en cualquier CPU.

Comprobación de que funciona sin red (ni caché ni GOPATH):

```bash
GOMODCACHE=/tmp/vacia GOPROXY=off go build ./...
```

Go usa `vendor/` automáticamente porque `go.mod` declara `go 1.22` (≥ 1.14).
Para forzar el modo vendor: `go build -mod=vendor ./...`.

### Si hay que tocar la dependencia (requiere red, una sola vez)

`go mod vendor` necesita descargar el módulo. Si `proxy.golang.org` está
bloqueado, se puede usar un mirror:

```bash
GOPROXY=https://goproxy.io,direct go mod vendor   # o goproxy.cn, o Athens
```

Alternativas: `GOPROXY=off` (solo caché local), `GOPROXY=direct` (descarga
directa del repositorio, sin proxy).

El módulo también está publicado en `github.com/godbus/dbus` con licencia
BSD-3-Clause; su `LICENSE` va incluido en `vendor/`.

## Cómo ejecutar

```bash
./shinro-backend
```

### Variables de entorno

| Variable | Descripción | Predeterminado |
|----------|-------------|----------------|
| `SHINRO_LOG_LEVEL` | Nivel de log: `debug`, `info`, `warn`, `error` | `info` |
| `SHINRO_CONNECTIVITY_INTERVAL` | Intervalo de chequeo de conectividad (p. ej. `30s`, `1m`) | `30s` |
| `SHINRO_CONNECTIVITY_URL` | URL usada para detectar si hay Internet | `http://www.google.com/generate_204` (con fallback) |
| `SHINRO_SOCKET_PATH` | Ruta del socket Unix | `$XDG_RUNTIME_DIR/shinro` o `/run/user/$UID/shinro` |
| `SHINRO_CONNECTIVITY_DISABLE_NM` | `1` desactiva la integración con NetworkManager (solo depuración) | *(desactivado)* |
| `SHINRO_WL_TRACE` | `1` vuelca el tráfico del protocolo Wayland a stderr (solo depuración) | *(desactivado)* |

**Ninguna de ellas es obligatoria**: con el entorno tal cual el daemon arranca
y funciona con los valores por defecto. Son únicamente puntos de ajuste.

Para ajustar sin editar la unidad systemd, se puede usar un fichero de
entorno opcional (el prefijo `-` de `EnvironmentFile` hace que systemd lo
ignore si no existe):

```ini
[Service]
EnvironmentFile=-%h/.config/shinro/backend.env
```

### Ruta del socket

El socket se resuelve siempre en el mismo orden, tanto en el backend como en
la CLI (`shinro-shell`) y en la shell (QML):

```
$SHINRO_SOCKET_PATH  →  $XDG_RUNTIME_DIR/shinro  →  /run/user/$UID/shinro
```

Se recomienda lanzar como servicio de usuario con systemd:

`~/.config/systemd/user/shinro-backend.service`

```ini
[Unit]
Description=shinro backend socket
After=graphical-session.target

[Service]
ExecStart=/home/oscar/.dotfiles/shinro-backend/shinro-backend
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Luego:
```bash
systemctl --user daemon-reload
systemctl --user enable --now shinro-backend
```

## Integración con Quickshell (shinro)

Quickshell incluye el componente `Quickshell.Io.Socket` para Unix sockets.
La shell de Quickshell en `.config/quickshell/Core/Services/` ya conecta
directamente al socket `shinro` (`WeatherService.qml` y
`SystemInfoService.qml`) y filtra por el campo `module` para recibir solo
los datos que le interesan.

## Notas

- El backend no es un microservicio: es un daemon local que habla por socket Unix.
- QML no lee socket Unix directamente desde QtQuick puro; se usa `Quickshell.Io.Socket`.
- Geoclue está integrado vía D-Bus con `github.com/godbus/dbus/v5`.
