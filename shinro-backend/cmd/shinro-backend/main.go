package main

import (
	"context"
	"errors"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"shinro-backend/internal/clipboard"
	"shinro-backend/internal/connectivity"
	"shinro-backend/internal/files"
	"shinro-backend/internal/ipc"
	"shinro-backend/internal/logger"
	"shinro-backend/internal/safe"
	"shinro-backend/internal/socket"
	"shinro-backend/internal/system"
	"shinro-backend/internal/updates"
	"shinro-backend/internal/weather"
)

func envDuration(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
		logger.Warn("valor inválido para variable de entorno", "key", key, "value", v, "usando_predeterminado", def)
	}
	return def
}

func main() {
	logger.Init()

	// Un panic en el hilo principal también debe quedar registrado con su
	// stack antes de terminar: sin esto, el daemon muere sin dejar rastro
	// útil en el journal.
	defer safe.Recover("shinro-backend.main")

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Bloqueo exclusivo del daemon: si ya hay otro shinro-backend en ejecución,
	// salimos inmediatamente (0 ms) con código 2 para que systemd
	// (con RestartPreventExitStatus=2) no lo reintente. Al bloquear antes de
	// inicializar los proveedores, evitamos abrir inotify o manipular la
	// base de datos del portapapeles si no somos la instancia dueña.
	socketPath, err := ipc.DefaultSocketPath()
	if err != nil {
		logger.Error("no se pudo resolver la ruta del socket", "error", err)
		os.Exit(1)
	}
	lockFile, err := socket.AcquireLock(socketPath)
	if err != nil {
		if errors.Is(err, socket.ErrAlreadyRunning) {
			logger.Warn("shinro-backend ya está en ejecución", "socket", socketPath)
			os.Exit(2)
		}
		logger.Error("no se pudo adquirir el bloqueo del socket", "socket", socketPath, "error", err)
		os.Exit(1)
	}
	defer lockFile.Close()

	// Cada proveedor es independiente y no conoce a los demás.
	sysProvider := system.New()
	weatherProvider := weather.New()

	// Vigila la conectividad a Internet para refrescar el clima nada más
	// recuperar la red, sin esperar al siguiente tick programado.
	// SHINRO_CONNECTIVITY_INTERVAL (p. ej. 30s, 1m) y SHINRO_CONNECTIVITY_URL
	//
	// Ambas variables son opcionales: con el entorno tal cual se usan los
	// valores por defecto.
	connURL := os.Getenv("SHINRO_CONNECTIVITY_URL")
	connInterval := envDuration("SHINRO_CONNECTIVITY_INTERVAL", 30*time.Second)
	connMon := connectivity.New(connURL, connInterval)

	// Conectar el monitor de conectividad con el proveedor de clima para
	// servir caché instantáneamente cuando no hay red y refrescar al volver.
	weatherProvider.SetConnectivityCheck(connMon.IsOnline)

	// Registro de módulos: añadir un módulo nuevo solo requiere crear una
	// implementación de socket.Module y registrarla aquí.
	registry := socket.NewDefaultRegistry(sysProvider, weatherProvider)

	// Actualizaciones: detecta el gestor de sistema según la distro base
	// (leyendo /etc/os-release) y añade AUR/Flatpak si están disponibles.
	// El estado vive solo en RAM y la comprobación se comparte entre clientes.
	updatesProvider := updates.New(
		updates.NewDetector().Detect(),
		updates.NewRunner(),
		connMon.IsOnline,
	)
	registry.Register(socket.NewUpdatesModule(updatesProvider))

	// Portapapeles: persiste el historial en XDG_STATE_HOME/shinro (o
	// ~/.local/state/shinro), que ya usaba el estado previo del módulo.
	stateDir := clipboardStateDir()
	clipProvider := clipboard.New(stateDir)
	clipModule := socket.NewClipboardModule(clipProvider)
	registry.Register(clipModule)

	// Al apagar, detener el watcher del portapapeles: su goroutine debe
	// terminar y el cliente Wayland debe soltar la selección, para no dejar
	// procesos o descriptores colgando al reiniciar el servicio.
	defer clipProvider.StopWatch()

	// Archivos: búsqueda difusa y concurrente en el sistema de archivos.
	//
	// El proveedor abre un descriptor de inotify para vigilar los cambios:
	// hay que cerrarlo al apagar, o el descriptor se queda abierto.
	filesProvider := files.New()
	registry.Register(socket.NewFilesModule(filesProvider))
	defer filesProvider.Close()

	// Un único socket Unix llamado "shinro" para todo.
	// SHINRO_SOCKET_PATH permite sobrescribir la ruta del socket.
	srv := socket.NewServer(registry, connMon)
	srv.SetLockFile(lockFile)

	// El proveedor de clima descarga el feed de avisos (2,7 MB) en segundo
	// plano. Cuando llega, se despierto a los clientes de clima para que
	// muestren los avisos sin esperar al siguiente tick.
	weatherProvider.SetOnChange(srv.WakeOnlineClients)

	// El broadcast del portapapeles empuja el historial a los clientes
	// suscritos cada vez que el historial cambia (nueva copia, borrado,
	// starred...). Se conecta después de crear el servidor porque necesita
	// acceso a wakeClipboardClients.
	clipModule.SetBroadcast(func() { srv.WakeClipboardClients() })

	// El módulo de actualizaciones avisa del progreso (comprobando,
	// actualizando) a los clientes suscritos.
	updatesProvider.SetBroadcast(srv.WakeUpdateClients)

	if err := srv.Start(ctx); err != nil {
		if errors.Is(err, socket.ErrAlreadyRunning) {
			logger.Warn("shinro-backend ya está en ejecución", "error", err)
			os.Exit(2)
		}
		logger.Error("shinro-backend fatal", "error", err)
		os.Exit(1)
	}
}

// clipboardStateDir devuelve el directorio de estado del portapapeles:
// XDG_STATE_HOME/shinro, o ~/.local/state/shinro como respaldo.
func clipboardStateDir() string {
	if d := os.Getenv("XDG_STATE_HOME"); d != "" {
		return filepath.Join(d, "shinro")
	}
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return ""
	}
	return filepath.Join(home, ".local", "state", "shinro")
}

