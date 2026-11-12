package socket

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"sync/atomic"
	"testing"
	"time"

	"shinro-backend/internal/connectivity"
	"shinro-backend/internal/logger"
	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

// redirectTransport reescribe cualquier petición HTTP hacia el servidor de prueba.
type redirectTransport struct {
	target string
}

func (rt *redirectTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	req.URL.Scheme = "http"
	req.URL.Host = rt.target
	return http.DefaultTransport.RoundTrip(req)
}

func TestWeatherImmediateUpdateOnHelloAndRefreshOnOnline(t *testing.T) {
	logger.Init()

	// Desactivar NM para controlar la conectividad mediante el mock HTTP
	os.Setenv("SHINRO_CONNECTIVITY_DISABLE_NM", "1")
	defer os.Unsetenv("SHINRO_CONNECTIVITY_DISABLE_NM")

	var isOnline int32 = 1
	var tempValue int32 = 20

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if atomic.LoadInt32(&isOnline) == 0 {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}

		currTemp := atomic.LoadInt32(&tempValue)
		switch {
		case r.URL.Path == "/check":
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(`{"ok":true}`))
		case r.URL.Path == "/v1/forecast":
			w.Write([]byte(`{
				"current": {
					"temperature_2m": ` + jsonNumber(currTemp) + `,
					"relative_humidity_2m": 60,
					"apparent_temperature": ` + jsonNumber(currTemp) + `,
					"is_day": 1,
					"weather_code": 0,
					"wind_speed_10m": 5,
					"wind_direction_10m": 180
				},
				"hourly": {
					"time": ["2026-01-01T00:00"],
					"temperature_2m": [` + jsonNumber(currTemp) + `],
					"weather_code": [0]
				},
				"daily": {
					"time": ["2026-01-01"],
					"weather_code": [0],
					"temperature_2m_max": [25],
					"temperature_2m_min": [15]
				}
			}`))
		case r.URL.Path == "/v1/search":
			w.Write([]byte(`{"results":[{"name":"Madrid","latitude":40.4,"longitude":-3.7,"country_code":"ES"}]}`))
		default:
			w.Write([]byte(`{}`))
		}
	}))
	defer ts.Close()

	// Socket temporal
	tmpDir := t.TempDir()
	socketPath := tmpDir + "/shinro"
	os.Setenv("SHINRO_SOCKET_PATH", socketPath)
	defer os.Unsetenv("SHINRO_SOCKET_PATH")

	sysProvider := system.New()
	weatherProvider := weather.New()

	// Redirigir el cliente de weather al servidor de prueba
	host := ts.Listener.Addr().String()
	weatherProvider.SetHTTPTransport(&redirectTransport{target: host})

	connMon := connectivity.New(ts.URL+"/check", 50*time.Millisecond)
	weatherProvider.SetConnectivityCheck(connMon.IsOnline)

	registry := NewDefaultRegistry(sysProvider, weatherProvider)
	srv := NewServer(registry, connMon)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() { _ = srv.Start(ctx) }()

	// Esperar a que el socket exista
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(socketPath); err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	defer conn.Close()

	// 1. Suscribirse a weather con un intervalo largo (600s = 10 minutos)
	hello := map[string]interface{}{
		"type": "hello",
		"location": map[string]string{
			"mode": "manual",
			"city": "Madrid",
		},
		"intervals": map[string]int{
			"system":  0,
			"weather": 600, // 10 minutos
		},
		"lang": "es",
	}
	helloBytes, _ := json.Marshal(hello)
	if _, err := conn.Write(append(helloBytes, '\n')); err != nil {
		t.Fatalf("error enviando hello: %v", err)
	}

	// 2. Comprobar que hello es respondido de inmediato
	line, err := readLine(conn, 3*time.Second)
	if err != nil {
		t.Fatalf("timeout esperando respuesta hello: %v", err)
	}
	var helloResp map[string]interface{}
	if err := json.Unmarshal([]byte(line), &helloResp); err != nil {
		t.Fatalf("error parseando hello: %v", err)
	}
	if helloResp["type"] != "hello" || helloResp["ok"] != true {
		t.Fatalf("esperaba hello ok=true, got: %v", line)
	}

	// 3. Comprobar que el clima se entrega DE INMEDIATO sin esperar a los 600 segundos
	updateLine, err := readLine(conn, 3*time.Second)
	if err != nil {
		t.Fatalf("timeout esperando primer update de weather al suscribirse: %v", err)
	}
	var updateMsg map[string]interface{}
	if err := json.Unmarshal([]byte(updateLine), &updateMsg); err != nil {
		t.Fatalf("error parseando primer update: %v", err)
	}
	if updateMsg["module"] != "weather" {
		t.Fatalf("esperaba update de weather, got %v", updateMsg["module"])
	}
	data := updateMsg["data"].(map[string]interface{})
	current := data["current"].(map[string]interface{})
	if temp := current["temperature_2m"].(float64); temp != 20 {
		t.Fatalf("esperaba temperatura 20, got %v", temp)
	}
	t.Log("Primer update de clima recibido de inmediato tras suscribirse")

	// 4. Simular caída de Internet
	atomic.StoreInt32(&isOnline, 0)
	time.Sleep(150 * time.Millisecond) // esperar que monitor detecte offline

	// Cambiar valor de temperatura en el servidor
	atomic.StoreInt32(&tempValue, 28)

	// 5. Simular recuperación de Internet: pasar de no tener a tener
	atomic.StoreInt32(&isOnline, 1)

	// 6. El backend debe forzar un refresco automático y empujar el nuevo clima al cliente
	refreshLine, err := readLine(conn, 4*time.Second)
	if err != nil {
		t.Fatalf("timeout esperando refresco automático de weather tras volver online: %v", err)
	}
	var refreshMsg map[string]interface{}
	if err := json.Unmarshal([]byte(refreshLine), &refreshMsg); err != nil {
		t.Fatalf("error parseando update de refresco: %v", err)
	}
	if refreshMsg["module"] != "weather" {
		t.Fatalf("esperaba update de weather tras reconexión, got %v", refreshMsg["module"])
	}
	refreshedData := refreshMsg["data"].(map[string]interface{})
	refreshedCurrent := refreshedData["current"].(map[string]interface{})
	if temp := refreshedCurrent["temperature_2m"].(float64); temp != 28 {
		t.Fatalf("esperaba temperatura actualizada 28, got %v", temp)
	}
	t.Log("Refresco automático recibido exitosamente tras transición offline -> online!")
}

func jsonNumber(n int32) string {
	b, _ := json.Marshal(n)
	return string(b)
}
