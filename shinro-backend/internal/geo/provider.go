// Package geo gestiona la ubicación: automática vía Geoclue (D-Bus) o manual
// por ciudad. Es independiente de system y weather.
package geo

import (
	"errors"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"
)

// Mode define cómo se obtiene la ubicación.
type Mode string

const (
	ModeAuto   Mode = "auto"   // Usar Geoclue
	ModeManual Mode = "manual" // Ciudad fija provista por la shell
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
	// SetAuto activa Geoclue; fallbackCity se usa si Geoclue no está
	// disponible o no devuelve coordenadas.
	SetAuto(fallbackCity string)
}

// geoclue2 D-Bus paths
const (
	geoclueBusName     = "org.freedesktop.GeoClue2"
	geoclueObjectPath  = "/org/freedesktop/GeoClue2/Manager"
	geoclueIface       = "org.freedesktop.GeoClue2.Manager"
	geoclueClientIface = "org.freedesktop.GeoClue2.Client"
)

type provider struct {
	// mu protege el estado compartido que leen los pumps y escriben los
	// hellos de cada cliente. Las llamadas D-Bus se hacen fuera de este
	// mutex para no bloquear a otros clientes.
	mu sync.Mutex

	// clientMu serializa la creación/liberación del cliente Geoclue.
	clientMu sync.Mutex

	conn   *dbus.Conn
	mode   Mode
	city   string
	lat    float64
	lon    float64
	client dbus.BusObject
	geoOK  bool // true si Geoclue está disponible en D-Bus
}

// New crea un proveedor de ubicación. Intenta conectar a Geoclue vía D-Bus.
// Si Geoclue no está disponible, el proveedor funciona en modo manual sin fallar.
func New() Provider {
	p := &provider{
		mode: ModeManual,
	}

	// Conectar al bus de sesión (donde vive Geoclue en sesión de usuario)
	conn, err := dbus.SessionBus()
	if err != nil {
		log.Printf("geo: no se pudo conectar al bus de sesión D-Bus: %v (modo manual solo)", err)
		return p
	}
	p.conn = conn

	// Verificar que Geoclue esté disponible en el bus usando Introspect.
	// GetClients puede no existir en todas las versiones de Geoclue.
	managerObj := conn.Object(geoclueBusName, dbus.ObjectPath(geoclueObjectPath))
	var introspectData string
	err = managerObj.Call("org.freedesktop.DBus.Introspectable.Introspect", 0).Store(&introspectData)
	if err != nil {
		log.Printf("geo: Geoclue no disponible en D-Bus: %v (modo manual solo)", err)
		return p
	}
	p.geoOK = true
	log.Println("geo: Geoclue detectado en D-Bus, modo automático disponible")

	return p
}

// SetManual configura ubicación manual por ciudad.
func (p *provider) SetManual(city string) {
	p.mu.Lock()
	p.mode = ModeManual
	p.city = city
	p.lat = 0
	p.lon = 0
	p.mu.Unlock()

	p.clientMu.Lock()
	p.releaseClientLocked()
	p.clientMu.Unlock()
}

// SetAuto solicita ubicación automática vía Geoclue. Si Geoclue no está
// disponible (o falla al arrancar), se conserva fallbackCity como ubicación
// manual para que el clima siga funcionando.
func (p *provider) SetAuto(fallbackCity string) {
	p.clientMu.Lock()
	defer p.clientMu.Unlock()

	p.mu.Lock()
	p.lat = 0
	p.lon = 0
	p.city = fallbackCity
	geoOK := p.geoOK
	p.mu.Unlock()

	if !geoOK || p.conn == nil {
		p.mu.Lock()
		p.mode = ModeManual
		p.mu.Unlock()
		p.releaseClientLocked()
		if fallbackCity != "" {
			log.Printf("geo: Geoclue no disponible en D-Bus; usando ciudad de respaldo %q", fallbackCity)
		} else {
			log.Println("geo: Geoclue no disponible en D-Bus y sin ciudad de respaldo")
		}
		return
	}

	p.mu.Lock()
	p.mode = ModeAuto
	p.mu.Unlock()

	// No dejar clientes Geoclue huérfanos si se vuelve a pedir auto.
	p.releaseClientLocked()
	p.createGeoclueClient()
}

// releaseClientLocked libera el cliente Geoclue actual. El llamador debe
// tener clientMu tomado.
func (p *provider) releaseClientLocked() {
	p.mu.Lock()
	client := p.client
	p.client = nil
	p.mu.Unlock()
	if client != nil {
		_ = client.Call(geoclueClientIface+".Release", 0)
	}
}

// Location devuelve la ubicación actual.
func (p *provider) Location() (Location, error) {
	// Copiar el estado bajo lock y hacer D-Bus fuera: así un hello de otro
	// cliente no bloquea a los pumps que están leyendo la ubicación.
	p.mu.Lock()
	mode := p.mode
	city := p.city
	lat := p.lat
	lon := p.lon
	client := p.client
	geoOK := p.geoOK
	p.mu.Unlock()

	if mode == ModeManual {
		return Location{
			Mode: ModeManual,
			City: city,
			Lat:  lat,
			Lon:  lon,
		}, nil
	}

	if !geoOK {
		if city != "" {
			return Location{Mode: ModeManual, City: city}, nil
		}
		return Location{}, errors.New("geoclue no disponible en D-Bus; use modo manual con city")
	}

	if client == nil {
		if city != "" {
			return Location{Mode: ModeManual, City: city}, nil
		}
		return Location{}, errors.New("cliente Geoclue no inicializado; llame a SetAuto primero")
	}

	// Obtener propiedades del cliente Geoclue
	var props map[string]dbus.Variant
	err := client.Call(geoclueClientIface+".GetProperties", 0).Store(&props)
	if err != nil {
		if city != "" {
			return Location{Mode: ModeManual, City: city}, nil
		}
		return Location{}, fmt.Errorf("obtener propiedades Geoclue: %w", err)
	}

	gpsLat, gpsLon := extractCoords(props)
	gpsCity := extractCity(props)

	// Sin fix válido: caer a la ciudad de respaldo si la hay.
	if gpsLat == 0 && gpsLon == 0 {
		if city != "" {
			return Location{Mode: ModeManual, City: city}, nil
		}
		return Location{}, errors.New("Geoclue no devolvió coordenadas; use modo manual con city")
	}

	return Location{
		Mode: ModeAuto,
		City: gpsCity,
		Lat:  gpsLat,
		Lon:  gpsLon,
	}, nil
}

// createGeoclueClient crea un cliente Geoclue, configura propiedades y lo inicia.
// El llamador debe tener clientMu tomado.
func (p *provider) createGeoclueClient() {
	managerObj := p.conn.Object(geoclueBusName, dbus.ObjectPath(geoclueObjectPath))

	var clientPath dbus.ObjectPath
	err := managerObj.Call(geoclueIface+".CreateClient", 0).Store(&clientPath)
	if err != nil {
		log.Printf("geo: no se pudo crear cliente Geoclue: %v", err)
		return
	}

	client := p.conn.Object(geoclueBusName, clientPath)

	// Configurar el cliente: nivel de precisión ciudad y permiso permitido
	props := map[string]dbus.Variant{
		"AccuracyLevel": dbus.MakeVariant(uint32(2)), // ciudad
		"Allowed":       dbus.MakeVariant(true),
	}
	err = client.Call(geoclueClientIface+".SetProperties", 0, props).Store(&struct{}{})
	if err != nil {
		log.Printf("geo: no se pudieron establecer propiedades Geoclue: %v", err)
	}

	// Iniciar el cliente para que empiece a obtener ubicación
	var started bool
	err = client.Call(geoclueClientIface+".Start", 0).Store(&started)
	if err != nil || !started {
		log.Printf("geo: no se pudo iniciar cliente Geoclue (err=%v, started=%v)", err, started)
		return
	}

	p.mu.Lock()
	p.client = client
	p.mu.Unlock()

	// Pequeña espera para que Geoclue recopile el primer fix antes de que
	// el hello dispare el snapshot inmediato.
	time.Sleep(2 * time.Second)
}

// extractCoords extrae latitud y longitud de las propiedades de Geoclue.
func extractCoords(props map[string]dbus.Variant) (float64, float64) {
	var lat, lon float64

	if v, ok := props["Latitude"]; ok {
		switch val := v.Value().(type) {
		case float64:
			lat = val
		case int64:
			lat = float64(val)
		case uint32:
			lat = float64(val)
		}
	}
	if v, ok := props["Longitude"]; ok {
		switch val := v.Value().(type) {
		case float64:
			lon = val
		case int64:
			lon = float64(val)
		case uint32:
			lon = float64(val)
		}
	}
	return lat, lon
}

// extractCity intenta extraer el nombre de la ciudad de Geoclue.
func extractCity(props map[string]dbus.Variant) string {
	// Geoclue puede proporcionar Address como un mapa con claves como "city", "town", etc.
	if v, ok := props["Address"]; ok {
		if addr, ok := v.Value().(map[string]string); ok {
			if city, ok := addr["city"]; ok {
				return city
			}
			if city, ok := addr["town"]; ok {
				return city
			}
		}
	}
	return ""
}
