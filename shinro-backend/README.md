# shinro-backend

Backend ligero en Go para la shell **shinro** (Quickshell). Expone un único
socket Unix llamado `shinro` por el que la shell obtiene recursos del sistema
y clima, de forma independiente y modular.

## Estructura

```
shinro-backend/
├── cmd/shinro-backend/main.go         # punto de entrada
├── internal/system                    # RAM, CPU, swap, uptime, temperatura (/proc, /sys)
├── internal/weather                   # clima (wttr.in / Open-Meteo)
├── internal/geo                       # ubicación: Geoclue (D-Bus) o ciudad (manual)
├── internal/socket                    # servidor Unix socket, protocolo JSON
├── go.mod
├── go.sum
└── README.md
```

Cada paquete es independiente: `system` no conoce a `weather`, y viceversa.
Se comunican solo a través del servidor del socket.

## Protocolo (socket Unix)

El socket se crea en `/run/user/$UID/shinro` con permisos `0660`.
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
{"type":"update","module":"system","data":{"ram_percent":34,"cpu_percent":12,"swap_percent":4,"uptime_seconds":12000,"temperature_c":55}}
```

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

### Consulta puntual (`get`)

```json
{"type":"get","module":"system"}
```
o
```json
{"type":"get","module":"weather"}
```

## Geoclue (ubicación automática)

El backend intenta conectar a GeoClue2 vía D-Bus de sesión (`org.freedesktop.GeoClue2`).
- Si Geoclue está disponible, `"mode": "auto"` usa sus coordenadas.
- Si no está disponible, falla o no devuelve un fix, se usa la `city` enviada
  en el `hello` como ubicación de respaldo. Así `"mode": "auto"` sigue
  funcionando con una ciudad fija aunque Geoclue no esté instalado/activo.
- Si tampoco hay ciudad de respaldo, el clima devuelve un error explícito.

## Cómo compilar

```bash
cd /home/oscar/.dotfiles/shinro-backend
go mod tidy
go build -o shinro-backend ./cmd/shinro-backend
```

## Cómo ejecutar

```bash
./shinro-backend
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
