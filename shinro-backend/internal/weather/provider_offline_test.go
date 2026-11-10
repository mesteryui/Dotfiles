package weather

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type failingTransport struct{}

func (failingTransport) RoundTrip(*http.Request) (*http.Response, error) {
	return nil, io.ErrUnexpectedEOF
}

type testServer struct {
	forecast string
}

func (ts *testServer) handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	switch {
	case strings.Contains(r.URL.Path, "/v1/forecast"):
		w.Write([]byte(ts.forecast))
	case strings.Contains(r.URL.Path, "/v1/air-quality"):
		w.Write([]byte(`{"current":{"european_aqi":45}}`))
	case strings.Contains(r.URL.Path, "/v1/search"):
		w.Write([]byte(`{"results":[{"name":"Vigo","latitude":42.24,"longitude":-8.72,"country_code":"ES","admin1":"Galicia"}]}`))
	case strings.Contains(r.URL.Path, "/reverse-geocode-client"):
		w.Write([]byte(`{"city":"Vigo","countryCode":""}`))
	default:
		w.WriteHeader(http.StatusNotFound)
	}
}

func forecastJSON(temp float64) string {
	return fmt.Sprintf(`{
		"current": {
			"temperature_2m": %g,
			"relative_humidity_2m": 60,
			"apparent_temperature": %g,
			"is_day": 1,
			"precipitation": 0,
			"weather_code": 0,
			"surface_pressure": 1015,
			"wind_speed_10m": 5,
			"wind_direction_10m": 180
		},
		"hourly": {
			"time": ["2026-01-01T00:00"],
			"temperature_2m": [%g],
			"relative_humidity_2m": [60],
			"precipitation_probability": [0],
			"weather_code": [0],
			"visibility": [10000],
			"is_day": [0]
		},
		"daily": {
			"time": ["2026-01-01"],
			"weather_code": [0],
			"temperature_2m_max": [20],
			"temperature_2m_min": [10],
			"sunrise": ["08:00"],
			"sunset": ["18:00"],
			"uv_index_max": [2],
			"precipitation_probability_max": [0]
		}
	}`, temp, temp, temp)
}

func newClient(transport http.RoundTripper) *http.Client {
	return &http.Client{Timeout: 5 * time.Second, Transport: transport}
}

// redirectTransport reescribe cualquier URL al test server para poder usar
// httptest en los clientes HTTP del proveedor, conservando path y query.
type redirectTransport struct {
	target string
}

func (rt *redirectTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	req.URL.Scheme = "http"
	req.URL.Host = strings.TrimPrefix(rt.target, "http://")
	return http.DefaultTransport.RoundTrip(req)
}

func TestSnapshotServesCacheWhenOffline(t *testing.T) {
	// 1. Sin red y sin caché previo: debe devolver error.
	w := New()
	w.client = newClient(failingTransport{})
	w.alertsClient = newClient(failingTransport{})
	if _, err := w.Snapshot("Vigo", "es"); err == nil {
		t.Fatal("esperaba error sin red ni caché previo")
	}

	// 2. Con red: obtenemos datos válidos y se guardan en caché.
	ts := &testServer{forecast: forecastJSON(18.5)}
	srv := httptest.NewServer(http.HandlerFunc(ts.handler))
	defer srv.Close()

	w.client = newClient(&redirectTransport{target: srv.URL})
	w.alertsClient = newClient(&redirectTransport{target: srv.URL})

	snap, err := w.Snapshot("Vigo", "es")
	if err != nil {
		t.Fatalf("esperaba éxito con red: %v", err)
	}
	if snap.Offline {
		t.Fatal("no debería estar offline con red")
	}
	if snap.Current.Temperature2M != 18.5 {
		t.Fatalf("esperaba 18.5, got %v", snap.Current.Temperature2M)
	}

	// 3. Volver a caer la red: debe servir el caché marcado como offline.
	w.client = newClient(failingTransport{})
	w.alertsClient = newClient(failingTransport{})

	snap, err = w.Snapshot("Vigo", "es")
	if err != nil {
		t.Fatalf("esperaba caché offline sin error: %v", err)
	}
	if !snap.Offline {
		t.Fatal("esperaba datos marcados como offline")
	}
	if snap.Current.Temperature2M != 18.5 {
		t.Fatalf("esperaba caché 18.5, got %v", snap.Current.Temperature2M)
	}

	// 4. Recuperar la red con datos diferentes: se refresca y se actualiza el caché.
	ts.forecast = forecastJSON(25.0)
	w.client = newClient(&redirectTransport{target: srv.URL})
	w.alertsClient = newClient(&redirectTransport{target: srv.URL})
	snap, err = w.Snapshot("Vigo", "es")
	if err != nil {
		t.Fatalf("esperaba éxito tras recuperar red: %v", err)
	}
	if snap.Offline {
		t.Fatal("no debería estar offline tras recuperar la red")
	}
	if snap.Current.Temperature2M != 25.0 {
		t.Fatalf("esperaba 25.0 tras refrescar, got %v", snap.Current.Temperature2M)
	}
}
