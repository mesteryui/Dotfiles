// Package geo define los tipos de ubicación que comparten los módulos del
// backend.
//
// El backend NO obtiene la ubicación por su cuenta: la resuelve la shell
// (Quickshell, con su PositionSource) y se la envía en el mensaje de hello.
// Este paquete solo aporta el vocabulario común para hablar de una
// ubicación:
//
//   - Mode: cómo se ha resuelto la ubicación.
//
//   - Location: el resultado (ciudad, coordenadas).
//
// No hay ninguna implementación de proveedor aquí: la geolocalización
// automática (Geoclue) vive en el cliente, no en el backend.
package geo

// Mode define cómo se obtiene la ubicación.
type Mode string

const (
	// ModeManual: ciudad fija provista por la shell.
	ModeManual Mode = "manual"

	// ModeAuto: la shell resolvió la ubicación por su cuenta (por ejemplo con
	// Geoclue). El backend no lo implementa, pero la constante se conserva
	// porque el handshake de la shell puede enviar "auto" y ese valor se le
	// devuelve tal cual.
	ModeAuto Mode = "auto"
)

// Location es el resultado de geolocalización.
type Location struct {
	Mode Mode    `json:"mode"`
	City string  `json:"city"`
	Lat  float64 `json:"lat"`
	Lon  float64 `json:"lon"`
}
