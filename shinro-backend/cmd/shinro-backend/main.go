package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"shinro-backend/internal/connectivity"
	"shinro-backend/internal/logger"
	"shinro-backend/internal/socket"
	"shinro-backend/internal/system"
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

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Cada proveedor es independiente y no conoce a los demás.
	sysProvider := system.New()
	weatherProvider := weather.New()

	// Vigila la conectividad a Internet para refrescar el clima nada más
	// recuperar la red, sin esperar al siguiente tick programado.
	// SHINRO_CONNECTIVITY_INTERVAL (p. ej. 30s, 1m) y SHINRO_CONNECTIVITY_URL
	connMon := connectivity.New(
		os.Getenv("SHINRO_CONNECTIVITY_URL"),
		envDuration("SHINRO_CONNECTIVITY_INTERVAL", 30*time.Second),
	)

	logger.Info("conectividad", "interval", os.Getenv("SHINRO_CONNECTIVITY_INTERVAL"), "url", os.Getenv("SHINRO_CONNECTIVITY_URL"))

	// Registro de módulos: añadir un módulo nuevo solo requiere crear una
	// implementación de socket.Module y registrarla aquí.
	registry := socket.NewDefaultRegistry(sysProvider, weatherProvider)

	// Un único socket Unix llamado "shinro" para todo.
	// SHINRO_SOCKET_PATH permite sobrescribir la ruta del socket.
	srv := socket.NewServer(registry, connMon)
	if err := srv.Start(ctx); err != nil {
		logger.Error("shinro-backend fatal", "error", err)
		os.Exit(1)
	}
}
