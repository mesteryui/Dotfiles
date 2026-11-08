package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"shinro-backend/internal/geo"
	"shinro-backend/internal/socket"
	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Cada proveedor es independiente y no conoce a los demás.
	sysProvider := system.New()
	geoProvider := geo.New()
	weatherProvider := weather.New(geoProvider)

	// Un único socket Unix llamado "shinro" para todo.
	srv := socket.NewServer(sysProvider, weatherProvider, geoProvider)
	if err := srv.Start(ctx); err != nil {
		log.Fatalf("shinro-backend: %v", err)
	}
}
