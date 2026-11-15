package weather

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// cityTestServer devuelve un parte con una temperatura distinta por ciudad,
// para poder comprobar que la caché offline no se mezcla entre ciudades.
type cityTestServer struct{}

func (cityTestServer) handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	switch {
	case strings.Contains(r.URL.Path, "/v1/search"):
		// La ciudad pedida viaja en el parámetro "name".
		name := r.URL.Query().Get("name")
		lat, lon := "42.240000", "-8.720000"
		region := "Galicia"
		if name == "Madrid" {
			lat, lon = "40.416800", "-3.703800"
			region = "Comunidad de Madrid"
		}
		w.Write([]byte(`{"results":[{"name":"` + name +
			`","latitude":` + lat + `,"longitude":` + lon +
			`,"country_code":"ES","admin1":"` + region + `"}]}`))
	case strings.Contains(r.URL.Path, "/v1/air-quality"):
		w.Write([]byte(`{"current":{"european_aqi":45}}`))
	case strings.Contains(r.URL.Path, "/v1/forecast"):
		// La temperatura depende de las coordenadas: cada ciudad tiene la
		// suya.
		temp := 18.5
		if strings.HasPrefix(r.URL.Query().Get("latitude"), "40") {
			temp = 30.0
		}
		w.Write([]byte(forecastJSON(temp)))
	default:
		w.WriteHeader(http.StatusNotFound)
	}
}

// TestCacheOfflineEsPorCiudad comprueba que, al quedarse sin red, se sirve el
// parte de la ciudad pedida y no el de otra.
//
// Antes la caché era un único snapshot global: al cambiar de ciudad sin red
// se servía el parte de la ciudad anterior (con su etiqueta), que es
// información equivocada.
func TestCacheOfflineEsPorCiudad(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(cityTestServer{}.handler))
	defer srv.Close()

	w := New()
	w.client = newClient(&redirectTransport{target: srv.URL})
	w.alertsClient = newClient(&redirectTransport{target: srv.URL})

	if _, err := w.Snapshot("Vigo", "es"); err != nil {
		t.Fatalf("esperaba éxito con red: %v", err)
	}
	if _, err := w.Snapshot("Madrid", "es"); err != nil {
		t.Fatalf("esperaba éxito con red: %v", err)
	}

	// Caer la red.
	//
	// El proveedor tiene que saber que no hay red (como hace el monitor de
	// conectividad en producción): las cachés de TTL siguen sirviendo su
	// dato, pero el parte se marca como offline.
	w.SetConnectivityCheck(func() bool { return false })
	w.client = newClient(failingTransport{})
	w.alertsClient = newClient(failingTransport{})

	vigo, err := w.Snapshot("Vigo", "es")
	if err != nil {
		t.Fatalf("esperaba caché offline para Vigo: %v", err)
	}
	if !vigo.Offline {
		t.Fatal("esperaba datos marcados como offline")
	}
	if vigo.Current.Temperature2M != 18.5 {
		t.Fatalf("esperaba la caché de Vigo (18.5), got %v", vigo.Current.Temperature2M)
	}

	madrid, err := w.Snapshot("Madrid", "es")
	if err != nil {
		t.Fatalf("esperaba caché offline para Madrid: %v", err)
	}
	if !madrid.Offline {
		t.Fatal("esperaba datos marcados como offline")
	}
	if madrid.Current.Temperature2M != 30.0 {
		t.Fatalf("esperaba la caché de Madrid (30.0), got %v", madrid.Current.Temperature2M)
	}
	if madrid.CityLabel != "Madrid, Comunidad de Madrid" {
		t.Fatalf("esperaba la etiqueta de la ciudad pedida, got %q", madrid.CityLabel)
	}

	// Una ciudad sin caché no debe recibir el parte de otra.
	if _, err := w.Snapshot("Bilbao", "es"); err == nil {
		t.Fatal("esperaba error para una ciudad sin caché propia")
	}
}
