// Package geo gestiona la ubicación: solo modo manual (ciudad provista por Quickshell).
// La ubicación automática vía Geoclue la maneja Quickshell con su PositionSource;
// este backend solo recibe la ciudad y la usa para el clima.
package geo

import (
	"errors"
	"sync"
)

// Mode define cómo se obtiene la ubicación.
type Mode string

const (
	ModeAuto   Mode = "auto"   // Usar Geoclue (gestionado por Quickshell)
	ModeManual Mode = "manual" // Ciudad fija provista por Quickshell
)

// Location es el resultado de geolocalización.
type Location struct {
	Mode Mode    `json:"mode"`
	City string  `json:"city"`
	Lat  float64 `json:"lat"`
	Lon  float64 `json:"lon"`
}

// Provider es la interfaz de geolocalización.
type Provider interface {
	Location() (Location, error)
	SetManual(city string)
	SetAuto(fallbackCity string)
}

// provider implementa Provider en modo manual únicamente.
type provider struct {
	mu   sync.Mutex
	mode Mode
	city string
	lat  float64
	lon  float64
}

// New crea un proveedor de ubicación en modo manual.
// No se conecta a D-Bus ni a ningún servicio externo.
func New() Provider {
	return &provider{
		mode: ModeManual,
	}
}

// SetManual configura ubicación manual por ciudad.
func (p *provider) SetManual(city string) {
	p.mu.Lock()
	p.mode = ModeManual
	p.city = city
	p.lat = 0
	p.lon = 0
	p.mu.Unlock()
}

// SetAuto mantiene la ciudad de respaldo en modo manual.
// La ubicación automática se gestiona desde Quickshell.
func (p *provider) SetAuto(fallbackCity string) {
	p.mu.Lock()
	p.mode = ModeManual
	p.city = fallbackCity
	p.lat = 0
	p.lon = 0
	p.mu.Unlock()
}

// Location devuelve la ubicación actual (siempre modo manual).
func (p *provider) Location() (Location, error) {
	p.mu.Lock()
	mode := p.mode
	city := p.city
	lat := p.lat
	lon := p.lon
	p.mu.Unlock()

	if mode == ModeManual {
		return Location{
			Mode: ModeManual,
			City: city,
			Lat:  lat,
			Lon:  lon,
		}, nil
	}

	return Location{}, errors.New("modo automático no soportado en este backend")
}
