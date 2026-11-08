# Integración con Quickshell (shinro)

Esta carpeta contiene ejemplos de cómo integrar el backend `shinro-backend`
con la shell **shinro** (Quickshell) usando el componente `Quickshell.Io.Socket`.

## Componente Socket de Quickshell

Quickshell incluye `Quickshell.Io.Socket`, un componente QML para comunicación
por Unix sockets. No es necesario crear un archivo JSON intermedio: el socket
se lee directamente desde QML.

Documentación: https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Socket

```qml
import Quickshell.Io

Socket {
    id: shinroSocket
    path: "/run/user/1000/shinro"   // usar $XDG_RUNTIME_DIR para portabilidad
    connected: true
    onMessage: (msg) => {
        var data = JSON.parse(msg)
        console.log("Recibido:", data.module, data.data)
    }
    onError: (err) => {
        console.error("Error socket:", err)
    }
}
```

## Archivos de ejemplo

| Archivo | Descripción |
|---------|-------------|
| `ShinroSocket.qml` | Componente reutilizable que se conecta a shinro y expone propiedades |
| `SystemBar.qml` | Barra de sistema: lee `module === "system"` del socket |
| `WeatherWidget.qml` | Widget de clima: lee `module === "weather"` del socket |
| `shell.qml` | Ejemplo de integración en `shell.qml` de Quickshell |

## Cómo usar

1. Copia los archivos `.qml` a tu configuración de Quickshell (ej. `~/.config/quickshell/Features/` o `Core/`).
2. Asegúrate de que el backend `shinro-backend` esté corriendo (systemd --user).
3. Incluye los componentes en tu `shell.qml`.

## Flujo de datos

```
shinro-backend (Go)  ── socket Unix ──>  Quickshell.Io.Socket (QML)
```

El backend empuja actualizaciones periódicas (`type: "update"`) con el campo
`module` ("system" o "weather"). Cada componente QML filtra por ese campo y
actualiza su UI de forma reactiva.

## Envío de configuración inicial (handshake)

Al conectar, la shell debe enviar un mensaje `hello` indicando:
- `location.mode`: `"auto"` (Geoclue) o `"manual"` (ciudad)
- `location.city`: solo si es manual
- `intervals.system`: segundos entre actualizaciones de recursos
- `intervals.weather`: segundos entre actualizaciones de clima

Ejemplo en QML (dentro de `onConnected`):

```qml
shinroSocket.write(JSON.stringify({
    type: "hello",
    location: { mode: "manual", city: "Madrid" },
    intervals: { system: 5, weather: 600 }
}));
shinroSocket.flush();
```

## Reconexión automática

Si el backend se reinicia, el socket se cierra. Implementa reconexión con un
`Timer`:

```qml
Timer {
    interval: 1000
    running: !shinroSocket.connected
    repeat: true
    onTriggered: shinroSocket.connected = true
}
```
