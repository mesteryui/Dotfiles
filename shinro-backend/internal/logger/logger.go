// Package logger proporciona un logger estructurado basado en log/slog.
// El nivel se configura con la variable de entorno SHINRO_LOG_LEVEL
// (debug, info, warn, error). Por defecto es info.
package logger

import (
	"log/slog"
	"os"
	"strings"
)

var log *slog.Logger

// Init configura el logger. Debe llamarse al inicio de main.
func Init() {
	level := slog.LevelInfo
	if v := strings.ToLower(os.Getenv("SHINRO_LOG_LEVEL")); v != "" {
		switch v {
		case "debug":
			level = slog.LevelDebug
		case "warn", "warning":
			level = slog.LevelWarn
		case "error":
			level = slog.LevelError
		}
	}
	log = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: level}))
}

// l devuelve el logger inicializado, o slog.Default() como fallback.
func l() *slog.Logger {
	if log != nil {
		return log
	}
	return slog.Default()
}

// Debug registra un mensaje de nivel debug.
func Debug(msg string, args ...any) { l().Debug(msg, args...) }

// Info registra un mensaje de nivel info.
func Info(msg string, args ...any) { l().Info(msg, args...) }

// Warn registra un mensaje de nivel advertencia.
func Warn(msg string, args ...any) { l().Warn(msg, args...) }

// Error registra un mensaje de nivel error.
func Error(msg string, args ...any) { l().Error(msg, args...) }
