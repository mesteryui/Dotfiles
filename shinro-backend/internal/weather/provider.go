// Package weather obtiene el clima completo (actual, diario, horario, AQI y
// avisos) para la ubicación resuelta por geo.Provider. No conoce a system.
package weather

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"
	"unicode"

	"shinro-backend/internal/geo"
	"shinro-backend/internal/safe"
)

// Snapshot es el payload que se envía a la shell. Replica la forma de la
// respuesta de Open-Meteo (current/daily/hourly) para que el QML reutilice su
// misma lógica de formateo, y añade los campos que no vienen de ahí.
type Snapshot struct {
	Current   Current `json:"current"`
	Daily     Daily   `json:"daily"`
	Hourly    Hourly  `json:"hourly"`
	CityLabel string  `json:"_cityLabel"`
	AQI       int     `json:"_aqi"`
	Alerts    []Alert `json:"_alerts"`

	// Offline indica que los datos son de caché (último parte válido) porque
	// no hay conexión a Internet en este momento.
	Offline bool `json:"_offline"`

	// Campos planos de compatibilidad (barra / consumidores simples).
	City      string  `json:"city"`
	TempC     float64 `json:"temp_c"`
	Condition string  `json:"condition"`
	Humidity  int     `json:"humidity"`
}

// Current son las condiciones actuales de Open-Meteo.
type Current struct {
	Temperature2M       float64 `json:"temperature_2m"`
	RelativeHumidity2M  int     `json:"relative_humidity_2m"`
	ApparentTemperature float64 `json:"apparent_temperature"`
	IsDay               int     `json:"is_day"`
	Precipitation       float64 `json:"precipitation"`
	WeatherCode         int     `json:"weather_code"`
	SurfacePressure     float64 `json:"surface_pressure"`
	WindSpeed10M        float64 `json:"wind_speed_10m"`
	WindDirection10M    float64 `json:"wind_direction_10m"`
}

// Daily es la previsión diaria (4 días).
type Daily struct {
	Time                        []string  `json:"time"`
	WeatherCode                 []int     `json:"weather_code"`
	Temperature2MMax            []float64 `json:"temperature_2m_max"`
	Temperature2MMin            []float64 `json:"temperature_2m_min"`
	Sunrise                     []string  `json:"sunrise"`
	Sunset                      []string  `json:"sunset"`
	UVIndexMax                  []float64 `json:"uv_index_max"`
	PrecipitationProbabilityMax []int     `json:"precipitation_probability_max"`
}

// Hourly es la previsión por horas.
type Hourly struct {
	Time                     []string  `json:"time"`
	Temperature2M            []float64 `json:"temperature_2m"`
	RelativeHumidity2M       []int     `json:"relative_humidity_2m"`
	PrecipitationProbability []int     `json:"precipitation_probability"`
	WeatherCode              []int     `json:"weather_code"`
	Visibility               []float64 `json:"visibility"`
	IsDay                    []int     `json:"is_day"`
}

// Alert es un aviso MeteoAlarm ya filtrado para la zona.
type Alert struct {
	Level       int    `json:"level"`
	Event       string `json:"event"`
	Area        string `json:"area"`
	Onset       string `json:"onset"`
	Expires     string `json:"expires"`
	Description string `json:"description"`
}

// TTL de las cachés del proveedor.
//
// Open-Meteo actualiza las condiciones actuales cada ~15 min y la calidad del
// aire cada ~30 min: cachear más allá de eso no cuesta frescura real, pero
// ahorra las peticiones de red en cada refresco.
//
// La geocodificación no cambia nunca para una ciudad: se cachea mucho más.
const (
	weatherGeoTTL      = 24 * time.Hour
	weatherAQITTL      = 15 * time.Minute
	weatherForecastTTL = 5 * time.Minute
	weatherAlertsTTL   = 15 * time.Minute
)

// Provider consulta Open-Meteo y MeteoAlarm.
type Provider struct {
	client       *http.Client
	alertsClient *http.Client

	// flights deduplica peticiones simultáneas para la misma ubicación:
	// si dos clientes piden el mismo parte a la vez, solo se descarga una vez.
	flightsMu sync.Mutex
	flights   map[string]*flightCall

	// geoCache guarda las coordenadas ya resueltas por ciudad. Geocodificar
	// cuesta una petición de red completa y el resultado no cambia: sin
	// esta caché, cada refresco pagaba un RTT solo para obtener las mismas
	// coordenadas.
	geoMu    sync.Mutex
	geoCache map[string]geoCacheEntry

	// aqiCache guarda la última calidad del aire por coordenadas.
	aqiMu    sync.Mutex
	aqiCache map[string]aqiCacheEntry

	// forecastCache guarda el último parte de previsión por coordenadas.
	fcMu    sync.Mutex
	fcCache map[string]forecastCacheEntry

	// alertsFeeds cachea el feed MeteoAlarm crudo por país. El filtrado por
	// zona e idioma se hace después, así cambiar de ciudad dentro del mismo
	// país no vuelve a descargar ~2 MB.
	//
	// alertsFetching marca los feeds que se están descargando ahora, para no
	// lanzar dos descargas a la vez.
	alertsMu       sync.Mutex
	alertsFeeds    map[string]alertsFeedEntry
	alertsFetching map[string]bool

	// lastSnapshots guarda el último parte válido por ubicación (ciudad +
	// idioma) para servirlo mientras no haya conexión a Internet.
	//
	// Es un mapa y no un único snapshot porque la caché es por ciudad: si no,
	// al cambiar de ciudad sin red se serviría el parte de la ciudad
	// anterior (con su etiqueta), que es información equivocada.
	mu            sync.Mutex
	lastSnapshots map[string]cachedSnapshot

	// timings guarda el desglose del último parte (cuánto tardó cada
	// sub-petición), para poder ver dónde se va el tiempo.
	timingsMu sync.Mutex
	timings   snapshotTimings

	isOnlineFn func() bool
	onChangeFn func()
}

// snapshotTimings es el desglose temporal de un parte.
type snapshotTimings struct {
	Geocode  time.Duration
	Forecast time.Duration
	AQI      time.Duration
	Alerts   time.Duration
	Total    time.Duration
}

type flightCall struct {
	done chan struct{}
	snap Snapshot
	err  error
}

type alertsFeedEntry struct {
	data *meteoAlarmResponse
	at   time.Time
}

type geoCacheEntry struct {
	info geoInfo
	at   time.Time
}

type aqiCacheEntry struct {
	value int
	at    time.Time
}

type forecastCacheEntry struct {
	snap Snapshot
	at   time.Time
}

// cachedSnapshot es un parte cacheado junto con el momento en que se
// calculó, para poder descartar el más antiguo cuando la caché crece.
type cachedSnapshot struct {
	snap Snapshot
	at   time.Time
}

// newTransport crea un transporte HTTP reutilizable con keep-alive y pooling
// de conexiones, clave cuando el clima hace varias peticiones en paralelo.
func newTransport() *http.Transport {
	return &http.Transport{
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 10,
		IdleConnTimeout:     90 * time.Second,
		DisableCompression:  false,
	}
}

// New crea un proveedor de clima.
func New() *Provider {
	return &Provider{
		client:         &http.Client{Timeout: 10 * time.Second, Transport: newTransport()},
		alertsClient:   &http.Client{Timeout: 6 * time.Second, Transport: newTransport()},
		flights:        make(map[string]*flightCall),
		geoCache:       make(map[string]geoCacheEntry),
		aqiCache:       make(map[string]aqiCacheEntry),
		fcCache:        make(map[string]forecastCacheEntry),
		alertsFeeds:    make(map[string]alertsFeedEntry),
		alertsFetching: make(map[string]bool),
		lastSnapshots:  make(map[string]cachedSnapshot),
	}
}

// SetOnChange registra una función que se llama cuando el proveedor obtiene
// datos nuevos por su cuenta (por ejemplo, cuando llega el feed de avisos en
// segundo plano).
//
// La shell la usa para refrescar la precipitación en cuanto hay avisos
// nuevos, sin esperar al siguiente tick.
func (provider *Provider) SetOnChange(fn func()) {
	provider.mu.Lock()
	provider.onChangeFn = fn
	provider.mu.Unlock()
}

// notifyChanged avisa al consumidor de un cambio en los datos.
func (provider *Provider) notifyChanged() {
	provider.mu.Lock()
	fn := provider.onChangeFn
	provider.mu.Unlock()
	if fn != nil {
		fn()
	}
}

// InvalidateCaches descarta los datos cacheados.
//
// Se llama cuando la conectividad se recupera: si el daemon estuvo un rato
// sin red, lo cacheado puede tener horas y el usuario espera datos frescos.
//
// La geocodificación NO se invalida: las coordenadas de una ciudad no
// cambian, y volver a pedirlas sería tirar una petición de red a la basura.
func (provider *Provider) InvalidateCaches() {
	provider.fcMu.Lock()
	provider.fcCache = make(map[string]forecastCacheEntry)
	provider.fcMu.Unlock()

	provider.aqiMu.Lock()
	provider.aqiCache = make(map[string]aqiCacheEntry)
	provider.aqiMu.Unlock()

	provider.alertsMu.Lock()
	provider.alertsFeeds = make(map[string]alertsFeedEntry)
	provider.alertsMu.Unlock()
}

// expirarCachePrevision vacía la caché de previsión (solo para tests: simula
// que han pasado los 5 minutos de TTL).
func (provider *Provider) expirarCachePrevision() {
	provider.fcMu.Lock()
	provider.fcCache = make(map[string]forecastCacheEntry)
	provider.fcMu.Unlock()
}

// Timings devuelve el desglose del último parte: cuánto tardó cada
// sub-petición. Lo usa el informe de salud del módulo ping para ver dónde
// se va el tiempo.
func (provider *Provider) Timings() map[string]float64 {
	provider.timingsMu.Lock()
	defer provider.timingsMu.Unlock()
	t := provider.timings
	return map[string]float64{
		"geocode_ms":  float64(t.Geocode.Microseconds()) / 1000,
		"forecast_ms": float64(t.Forecast.Microseconds()) / 1000,
		"aqi_ms":      float64(t.AQI.Microseconds()) / 1000,
		"alerts_ms":   float64(t.Alerts.Microseconds()) / 1000,
		"total_ms":    float64(t.Total.Microseconds()) / 1000,
	}
}

// SetHTTPTransport permite sobrescribir el transporte HTTP (útil para pruebas unitarias).
func (provider *Provider) SetHTTPTransport(transport http.RoundTripper) {
	provider.client.Transport = transport
	provider.alertsClient.Transport = transport
}

// SetConnectivityCheck configura una función para comprobar si hay conexión a Internet.
func (provider *Provider) SetConnectivityCheck(fn func() bool) {
	provider.mu.Lock()
	defer provider.mu.Unlock()
	provider.isOnlineFn = fn
}

// IsOnline devuelve true si hay conexión a Internet conocida.
func (provider *Provider) IsOnline() bool {
	provider.mu.Lock()
	fn := provider.isOnlineFn
	provider.mu.Unlock()
	if fn != nil {
		return fn()
	}
	return true
}

// Snapshot devuelve todos los datos del parte para la ciudad dada.
func (provider *Provider) Snapshot(city string, lang string) (Snapshot, error) {
	if lang == "" {
		lang = "es"
	}

	// Si se sabe con certeza que no hay conexión, servir directamente la caché
	// sin esperar a que expiren los timeouts de red.
	if !provider.IsOnline() {
		if snap, ok := provider.cachedOrOffline(flightKey(geo.Location{Mode: geo.ModeManual, City: city}, lang)); ok {
			return snap, nil
		}
		return Snapshot{}, errors.New("sin conexión a Internet (sin datos en caché)")
	}

	loc := geo.Location{Mode: geo.ModeManual, City: city}
	key := flightKey(loc, lang)

	provider.flightsMu.Lock()
	if call, ok := provider.flights[key]; ok {
		provider.flightsMu.Unlock()
		// Hay otra petición en curso para la misma ubicación: esperar a que
		// termine en lugar de descargar el parte dos veces. El canal se
		// cierra SIEMPRE (ver runFlight), así que este follower nunca se
		// queda bloqueado aunque el líder entre en panic.
		<-call.done
		return call.snap, call.err
	}
	call := &flightCall{done: make(chan struct{})}
	provider.flights[key] = call
	provider.flightsMu.Unlock()

	provider.runFlight(key, call, loc, lang)

	return call.snap, call.err
}

// flightKey identifica una petición de parte: misma ubicación e idioma.
func flightKey(loc geo.Location, lang string) string {
	return fmt.Sprintf("%s|%s|%.6f|%.6f|%s", loc.Mode, loc.City, loc.Lat, loc.Lon, lang)
}

// runFlight calcula el parte de una ubicación y libera a los seguidores.
//
// Garantías:
//   - El canal done se cierra SIEMPRE, aunque el cálculo entre en panic:
//     ningún follower puede quedarse colgado esperando.
//   - La entrada de flights se elimina SIEMPRE: el mapa no crece sin
//     control (fuga de memoria) tras días de uso.
//   - Un panic se convierte en error, así el cliente recibe un error claro
//     en lugar de desaparecer el daemon.
func (provider *Provider) runFlight(key string, call *flightCall, loc geo.Location, lang string) {
	defer func() {
		provider.flightsMu.Lock()
		delete(provider.flights, key)
		provider.flightsMu.Unlock()
		close(call.done)
	}()

	var snap Snapshot
	err := safe.Do("weather.snapshot", func() error {
		var err error
		snap, err = provider.snapshotFor(loc, lang)
		return err
	})
	call.snap = snap
	call.err = err

	if call.err == nil {
		// Guardar el último parte válido para servirlo mientras falte red.
		provider.mu.Lock()
		provider.lastSnapshots[key] = cachedSnapshot{snap: call.snap, at: time.Now()}
		provider.pruneSnapshotsLocked()
		provider.mu.Unlock()
		return
	}

	// Sin red: servir el último parte válido marcado como offline, si lo
	// hay, para que el cliente no se quede sin datos. Si nunca hubo parte
	// válido, se propaga el error.
	if cached, ok := provider.cachedOrOffline(key); ok {
		call.snap = cached
		call.err = nil
	}
}

// maxWeatherCacheEntries limita el tamaño de las cachés del proveedor.
//
// Sin tope, buscar muchas ciudades distintas dejaría partes completos
// (cada previsión ocupa unos 10-20 KB) acumulados en memoria para siempre:
// el daemon es de larga vida y esa memoria nunca vuelve al sistema.
const maxWeatherCacheEntries = 8

// pruneCache descarta las entradas más antiguas de una caché hasta dejar
// como mucho maxWeatherCacheEntries.
//
// at devuelve la marca temporal de una entrada. Se usa con el lock de la
// caché cogido.
func pruneCache[T any](m map[string]T, at func(T) time.Time) {
	for len(m) > maxWeatherCacheEntries {
		var victim string
		var oldest time.Time
		primera := true
		for k, v := range m {
			t := at(v)
			if primera || t.Before(oldest) {
				victim, oldest, primera = k, t, false
			}
		}
		if victim == "" {
			return
		}
		delete(m, victim)
	}
}

// pruneSnapshotsLocked descarta la entrada más antigua de la caché de partes,
// dejando como mucho maxWeatherCacheEntries. Se llama con el lock cogido.
func (provider *Provider) pruneSnapshotsLocked() {
	pruneCache(provider.lastSnapshots, func(e cachedSnapshot) time.Time { return e.at })
}

// cachedOrOffline devuelve el último parte válido de la ubicación indicada,
// marcado como offline, si existe; si no, devuelve false.
func (provider *Provider) cachedOrOffline(key string) (Snapshot, bool) {
	provider.mu.Lock()
	defer provider.mu.Unlock()
	snap, ok := provider.lastSnapshots[key]
	if !ok {
		return Snapshot{}, false
	}
	out := snap.snap
	out.Offline = true
	return out, true
}

// snapshotFor hace el trabajo real del parte para una ubicación ya resuelta.
func (provider *Provider) snapshotFor(loc geo.Location, lang string) (Snapshot, error) {
	inicio := time.Now()
	var t snapshotTimings

	var lat, lon float64
	var cityLabel, countryCode string
	var tokens []string

	switch {
	case loc.Lat != 0 || loc.Lon != 0:
		lat, lon = loc.Lat, loc.Lon
		cityLabel = loc.City
		if rc, err := provider.reverseGeocode(lat, lon, lang); err == nil {
			if cityLabel == "" {
				cityLabel = rc.label
			}
			countryCode = rc.countryCode
			tokens = rc.tokens
		} else if cityLabel != "" {
			tokens = tokensFor(cityLabel)
		}
	case loc.City != "":
		t0 := time.Now()
		g, err := provider.geocode(loc.City, lang)
		t.Geocode = time.Since(t0)
		if err != nil {
			return Snapshot{}, fmt.Errorf("geocodificar %q: %w", loc.City, err)
		}
		lat, lon = g.lat, g.lon
		cityLabel = g.label
		countryCode = g.countryCode
		tokens = g.tokens
	default:
		return Snapshot{}, fmt.Errorf("sin ubicación válida para clima")
	}

	// Previsión, AQI y avisos son independientes una vez resueltas las
	// coordenadas: se piden en paralelo para minimizar la latencia.
	//
	// Cada petición va en su propia goroutine protegida: si una de ellas
	// entra en panic (respuesta malformada del proveedor), el panic se
	// recupera y se convierte en error. El resto del parte sigue su curso
	// y el daemon no se cae.
	var (
		fc          Snapshot
		forecastErr error
		aqi         = -1
		alerts      = make([]Alert, 0)
		wg          sync.WaitGroup
	)
	wg.Add(3)
	safe.Go("weather.forecast", func() {
		defer wg.Done()
		t0 := time.Now()
		fc, forecastErr = safe.DoValue("weather.forecast", func() (Snapshot, error) {
			return provider.fetchForecast(lat, lon)
		})
		t.Forecast = time.Since(t0)
	})
	safe.Go("weather.aqi", func() {
		defer wg.Done()
		t0 := time.Now()
		aqi, _ = safe.DoValue("weather.aqi", func() (int, error) {
			return provider.fetchAQI(lat, lon), nil
		})
		t.AQI = time.Since(t0)
	})
	safe.Go("weather.alerts", func() {
		defer wg.Done()
		t0 := time.Now()
		alerts, _ = safe.DoValue("weather.alerts", func() ([]Alert, error) {
			return provider.fetchAlerts(countryCode, tokens, lang), nil
		})
		t.Alerts = time.Since(t0)
	})
	wg.Wait()

	t.Total = time.Since(inicio)
	provider.timingsMu.Lock()
	provider.timings = t
	provider.timingsMu.Unlock()

	if forecastErr != nil {
		return Snapshot{}, forecastErr
	}

	return Snapshot{
		Current:   fc.Current,
		Daily:     fc.Daily,
		Hourly:    fc.Hourly,
		CityLabel: cityLabel,
		City:      cityLabel,
		TempC:     fc.Current.Temperature2M,
		Condition: weatherCodeToString(fc.Current.WeatherCode),
		Humidity:  fc.Current.RelativeHumidity2M,
		AQI:       aqi,
		Alerts:    alerts,
	}, nil
}

// ── Open-Meteo: previsión ────────────────────────────────────────

// fetchForecast obtiene la previsión, con caché.
//
// Open-Meteo actualiza sus datos cada ~15 minutos: con una caché de 5
// minutos, cuatro de cada cinco refrescos se resuelven sin tocar la red.
func (provider *Provider) fetchForecast(lat, lon float64) (Snapshot, error) {
	key := fmt.Sprintf("%.4f,%.4f", lat, lon)

	provider.fcMu.Lock()
	entry, ok := provider.fcCache[key]
	provider.fcMu.Unlock()
	if ok && time.Since(entry.at) < weatherForecastTTL {
		return entry.snap, nil
	}

	u := fmt.Sprintf(
		"https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f"+
			"&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,"+
			"precipitation,weather_code,surface_pressure,wind_speed_10m,wind_direction_10m"+
			"&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,"+
			"weather_code,visibility,is_day"+
			"&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,"+
			"uv_index_max,precipitation_probability_max"+
			"&forecast_days=4&timezone=auto&temperature_unit=celsius"+
			"&wind_speed_unit=kmh&precipitation_unit=mm",
		lat, lon,
	)

	var out Snapshot
	if err := provider.getJSON(u, &out); err != nil {
		return Snapshot{}, fmt.Errorf("Open-Meteo forecast: %w", err)
	}
	if len(out.Daily.Time) == 0 || len(out.Hourly.Time) == 0 {
		return Snapshot{}, fmt.Errorf("Open-Meteo forecast: respuesta sin daily/hourly")
	}

	provider.fcMu.Lock()
	provider.fcCache[key] = forecastCacheEntry{snap: out, at: time.Now()}
	pruneCache(provider.fcCache, func(e forecastCacheEntry) time.Time { return e.at })
	provider.fcMu.Unlock()
	return out, nil
}

// ── Open-Meteo: calidad del aire ────────────────────────────────

// fetchAQI obtiene la calidad del aire, con caché.
//
// La calidad del aire cambia cada media hora como mucho: volver a pedirla
// en cada refresco es gastar una petición de red para el mismo dato.
func (provider *Provider) fetchAQI(lat, lon float64) int {
	key := fmt.Sprintf("%.4f,%.4f", lat, lon)

	provider.aqiMu.Lock()
	entry, ok := provider.aqiCache[key]
	provider.aqiMu.Unlock()
	if ok && time.Since(entry.at) < weatherAQITTL {
		return entry.value
	}

	u := fmt.Sprintf(
		"https://air-quality-api.open-meteo.com/v1/air-quality"+
			"?latitude=%f&longitude=%f&current=european_aqi&timezone=auto",
		lat, lon,
	)
	var data struct {
		Current struct {
			EuropeanAQI *int `json:"european_aqi"`
		} `json:"current"`
	}
	if err := provider.getJSON(u, &data); err != nil || data.Current.EuropeanAQI == nil {
		// Un fallo no se cachea: se reintenta en el siguiente refresco.
		return -1
	}

	value := *data.Current.EuropeanAQI
	provider.aqiMu.Lock()
	provider.aqiCache[key] = aqiCacheEntry{value: value, at: time.Now()}
	pruneCache(provider.aqiCache, func(e aqiCacheEntry) time.Time { return e.at })
	provider.aqiMu.Unlock()
	return value
}

// ── Geocodificación ─────────────────────────────────────────────

type geoInfo struct {
	lat, lon    float64
	label       string
	countryCode string
	tokens      []string
}

type geocodeResult struct {
	Name        string  `json:"name"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	CountryCode string  `json:"country_code"`
	Admin1      string  `json:"admin1"`
	Admin2      string  `json:"admin2"`
	Admin3      string  `json:"admin3"`
	Admin4      string  `json:"admin4"`
}

// geocode resuelve la ciudad a coordenadas, con caché.
//
// Las coordenadas de una ciudad no cambian: geocodificarla en cada refresco
// es pagar una petición de red completa (cientos de ms) para obtener
// siempre lo mismo.
func (provider *Provider) geocode(city, lang string) (geoInfo, error) {
	key := strings.ToLower(city) + "|" + lang

	provider.geoMu.Lock()
	entry, ok := provider.geoCache[key]
	provider.geoMu.Unlock()
	if ok && time.Since(entry.at) < weatherGeoTTL {
		return entry.info, nil
	}

	info, err := provider.geocodeRemote(city, lang)
	if err != nil {
		return geoInfo{}, err
	}

	provider.geoMu.Lock()
	provider.geoCache[key] = geoCacheEntry{info: info, at: time.Now()}
	pruneCache(provider.geoCache, func(e geoCacheEntry) time.Time { return e.at })
	provider.geoMu.Unlock()
	return info, nil
}

// geocodeRemote hace la petición de geocodificación a Open-Meteo.
func (provider *Provider) geocodeRemote(city, lang string) (geoInfo, error) {
	parts := strings.SplitN(city, ",", 2)
	name := strings.TrimSpace(parts[0])
	countryCode := ""
	if len(parts) > 1 {
		countryCode = strings.ToUpper(strings.TrimSpace(parts[1]))
	}
	if name == "" {
		return geoInfo{}, fmt.Errorf("ciudad vacía")
	}

	u := "https://geocoding-api.open-meteo.com/v1/search?name=" + url.QueryEscape(name) +
		"&count=5&language=" + url.QueryEscape(lang) + "&format=json"

	var data struct {
		Results []geocodeResult `json:"results"`
	}
	if err := provider.getJSON(u, &data); err != nil {
		return geoInfo{}, err
	}
	if len(data.Results) == 0 {
		return geoInfo{}, fmt.Errorf("ciudad no encontrada")
	}

	pick := data.Results[0]
	if countryCode != "" {
		for _, r := range data.Results {
			if strings.EqualFold(r.CountryCode, countryCode) {
				pick = r
				break
			}
		}
	}

	return geoInfo{
		lat:         pick.Latitude,
		lon:         pick.Longitude,
		label:       buildCityLabel(pick.Name, pick.Admin1, city),
		countryCode: strings.ToUpper(pick.CountryCode),
		tokens:      tokensFor(pick.Name, pick.Admin1, pick.Admin2, pick.Admin3, pick.Admin4),
	}, nil
}

func (provider *Provider) reverseGeocode(lat, lon float64, lang string) (geoInfo, error) {
	u := fmt.Sprintf(
		"https://api.bigdatacloud.net/data/reverse-geocode-client"+
			"?latitude=%f&longitude=%f&localityLanguage=%s",
		lat, lon, url.QueryEscape(lang),
	)
	var data struct {
		City            string `json:"city"`
		Locality        string `json:"locality"`
		PrincipalSubdiv string `json:"principalSubdivision"`
		CountryCode     string `json:"countryCode"`
		CountryName     string `json:"countryName"`
	}
	if err := provider.getJSON(u, &data); err != nil {
		return geoInfo{}, err
	}
	place := data.City
	if place == "" {
		place = data.Locality
	}
	if place == "" && data.PrincipalSubdiv == "" && data.CountryName == "" {
		return geoInfo{}, fmt.Errorf("geocodificación inversa vacía")
	}
	return geoInfo{
		lat:         lat,
		lon:         lon,
		label:       buildCityLabel(place, data.PrincipalSubdiv, data.CountryName),
		countryCode: strings.ToUpper(data.CountryCode),
		tokens:      tokensFor(place, data.Locality, data.PrincipalSubdiv, data.CountryName),
	}, nil
}

// ── MeteoAlarm: avisos ──────────────────────────────────────────

type meteoParameter struct {
	ValueName string `json:"valueName"`
	Value     string `json:"value"`
}

type meteoArea struct {
	AreaDesc string `json:"areaDesc"`
}

type meteoInfo struct {
	Language    string           `json:"language"`
	Event       string           `json:"event"`
	Onset       string           `json:"onset"`
	Expires     string           `json:"expires"`
	Effective   string           `json:"effective"`
	Description string           `json:"description"`
	Parameter   []meteoParameter `json:"parameter"`
	Area        []meteoArea      `json:"area"`
}

type meteoAlert struct {
	Identifier string      `json:"identifier"`
	Status     string      `json:"status"`
	MsgType    string      `json:"msgType"`
	Info       []meteoInfo `json:"info"`
}

type meteoAlarmResponse struct {
	Warnings []struct {
		Alert meteoAlert `json:"alert"`
	} `json:"warnings"`
}

func (provider *Provider) fetchAlerts(countryCode string, tokens []string, lang string) []Alert {
	out := make([]Alert, 0)
	slug := alertsSlug(countryCode)
	if slug == "" || len(tokens) == 0 {
		return out
	}

	feed := provider.alertsFeed(slug)
	if feed == nil {
		return out
	}

	now := time.Now()
	seen := map[string]bool{}
	for _, warning := range feed.Warnings {
		a := warning.Alert
		if a.Status != "Actual" || (a.MsgType != "Alert" && a.MsgType != "Update") {
			continue
		}
		info := pickInfo(a.Info, lang)
		if info == nil {
			continue
		}
		level := alertLevel(info.Parameter)
		if level < 2 {
			continue
		}
		onset, errOnset := time.Parse(time.RFC3339, info.Onset)
		expires, errExpires := time.Parse(time.RFC3339, info.Expires)
		if errOnset != nil || errExpires != nil {
			continue
		}
		if expires.Before(now) || onset.After(now.Add(24*time.Hour)) {
			continue
		}
		for _, area := range info.Area {
			if !areaMatches(area.AreaDesc, tokens) {
				continue
			}
			key := a.Identifier + "|" + area.AreaDesc
			if seen[key] {
				continue
			}
			seen[key] = true
			out = append(out, Alert{
				Level:       level,
				Event:       info.Event,
				Area:        area.AreaDesc,
				Onset:       info.Onset,
				Expires:     info.Expires,
				Description: info.Description,
			})
		}
	}

	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Level != out[j].Level {
			return out[i].Level > out[j].Level
		}
		ti, _ := time.Parse(time.RFC3339, out[i].Onset)
		tj, _ := time.Parse(time.RFC3339, out[j].Onset)
		return ti.Before(tj)
	})

	return out
}

// alertsFeed devuelve el feed MeteoAlarm del país.
//
// El feed son ~2,7 MB y tarda varios segundos en descargarse: es, con
// diferencia, lo más lento del parte. Por eso NUNCA se descarga en el camino
// crítico del refresco:
//
//   - Si hay copia en caché, se devuelve tal cual (aunque esté caducada) y
//     la reposición se hace en segundo plano.
//   - Si no hay copia, se devuelve vacío y la descarga también se hace en
//     segundo plano: el usuario ve la temperatura al instante y los avisos
//     llegan en la siguiente actualización.
//
// Cuando la descarga en segundo plano termina, se avisa con notifyChanged
// para que la shell refresque el parte y muestre los avisos sin esperar al
// siguiente tick.
func (provider *Provider) alertsFeed(slug string) *meteoAlarmResponse {
	provider.alertsMu.Lock()
	entry, ok := provider.alertsFeeds[slug]
	fetching := provider.alertsFetching[slug]
	provider.alertsMu.Unlock()

	if ok && time.Since(entry.at) < weatherAlertsTTL {
		return entry.data
	}

	// Caducado o inexistente: reponer en segundo plano y servir lo que haya.
	// Nunca se espera aquí a una descarga de varios segundos.
	if !fetching {
		provider.startAlertsPrefetch(slug)
	}
	if ok {
		return entry.data
	}
	return nil
}

// startAlertsPrefetch lanza la descarga del feed en segundo plano.
//
// Solo se admite una descarga a la vez por país: si ya hay una en curso, no
// se lanza otra.
func (provider *Provider) startAlertsPrefetch(slug string) {
	provider.alertsMu.Lock()
	if provider.alertsFetching[slug] {
		provider.alertsMu.Unlock()
		return
	}
	provider.alertsFetching[slug] = true
	provider.alertsMu.Unlock()

	safe.Go("weather.alerts.prefetch", func() {
		defer func() {
			provider.alertsMu.Lock()
			delete(provider.alertsFetching, slug)
			provider.alertsMu.Unlock()
		}()

		data := provider.downloadAlertsFeed(slug)
		if data == nil {
			return
		}

		provider.alertsMu.Lock()
		provider.alertsFeeds[slug] = alertsFeedEntry{data: data, at: time.Now()}
		provider.alertsMu.Unlock()

		// Avisos nuevos: la shell puede refrescar el parte ya.
		provider.notifyChanged()
	})
}

// downloadAlertsFeed descarga el feed MeteoAlarm de un país.
func (provider *Provider) downloadAlertsFeed(slug string) *meteoAlarmResponse {
	var data meteoAlarmResponse
	if err := provider.getJSONWith(provider.alertsClient,
		"https://feeds.meteoalarm.org/api/v1/warnings/feeds-"+slug, &data); err != nil {
		return nil
	}
	return &data
}

func pickInfo(infos []meteoInfo, lang string) *meteoInfo {
	if len(infos) == 0 {
		return nil
	}
	want := strings.ToLower(strings.TrimSpace(lang))
	if len(want) > 2 {
		want = want[:2]
	}
	for i := range infos {
		if strings.HasPrefix(strings.ToLower(infos[i].Language), want) {
			return &infos[i]
		}
	}
	for i := range infos {
		if strings.HasPrefix(strings.ToLower(infos[i].Language), "en") {
			return &infos[i]
		}
	}
	return &infos[0]
}

func alertLevel(params []meteoParameter) int {
	for _, p := range params {
		if p.ValueName != "awareness_level" {
			continue
		}
		parts := strings.Split(p.Value, ";")
		if len(parts) < 2 {
			return 0
		}
		switch strings.ToLower(strings.TrimSpace(parts[1])) {
		case "red":
			return 4
		case "orange":
			return 3
		case "yellow":
			return 2
		}
		return 0
	}
	return 0
}

func alertsSlug(countryCode string) string {
	switch strings.ToUpper(strings.TrimSpace(countryCode)) {
	case "ES":
		return "spain"
	case "PT":
		return "portugal"
	case "FR":
		return "france"
	case "DE":
		return "germany"
	case "IT":
		return "italy"
	}
	return ""
}

// ── Utilidades ──────────────────────────────────────────────────

func (provider *Provider) getJSON(u string, dst any) error {
	return provider.getJSONWith(provider.client, u, dst)
}

func (provider *Provider) getJSONWith(client *http.Client, u string, dst any) error {
	resp, err := client.Get(u)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if err != nil {
		return err
	}
	return json.Unmarshal(body, dst)
}

func buildCityLabel(place, region, fallback string) string {
	place = strings.TrimSpace(place)
	region = strings.TrimSpace(region)
	if place != "" && region != "" {
		if strings.EqualFold(place, region) ||
			strings.Contains(strings.ToLower(place), strings.ToLower(region)) {
			return place
		}
		return place + ", " + region
	}
	if place != "" {
		return place
	}
	if region != "" {
		return region
	}
	return fallback
}

var accentReplacer = strings.NewReplacer(
	"á", "a", "à", "a", "ä", "a", "â", "a", "ã", "a",
	"é", "e", "è", "e", "ë", "e", "ê", "e",
	"í", "i", "ì", "i", "ï", "i", "î", "i",
	"ó", "o", "ò", "o", "ö", "o", "ô", "o", "õ", "o",
	"ú", "u", "ù", "u", "ü", "u", "û", "u",
	"ñ", "n", "ç", "c",
)

func normalize(s string) string {
	return accentReplacer.Replace(strings.ToLower(s))
}

func tokensFor(parts ...string) []string {
	stop := map[string]bool{
		"de": true, "la": true, "el": true, "las": true, "los": true,
		"del": true, "les": true, "y": true, "en": true, "et": true,
		"the": true, "of": true, "provincia": true, "comunidad": true,
		"autonoma": true, "ciudad": true, "region": true, "departamento": true,
	}
	seen := map[string]bool{}
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		words := strings.FieldsFunc(normalize(part), func(r rune) bool {
			return !unicode.IsLetter(r) && !unicode.IsDigit(r)
		})
		for _, word := range words {
			if len([]rune(word)) < 4 || stop[word] || seen[word] {
				continue
			}
			seen[word] = true
			out = append(out, word)
		}
	}
	return out
}

func areaMatches(desc string, tokens []string) bool {
	norm := normalize(desc)
	for _, token := range tokens {
		if strings.Contains(norm, token) {
			return true
		}
	}
	return false
}

func weatherCodeToString(code int) string {
	codes := map[int]string{
		0:  "despejado",
		1:  "mayormente despejado",
		2:  "parcialmente nublado",
		3:  "nublado",
		45: "niebla",
		48: "niebla escarchada",
		51: "llovizna ligera",
		53: "llovizna",
		55: "llovizna intensa",
		61: "lluvia ligera",
		63: "lluvia",
		65: "lluvia intensa",
		71: "nieve ligera",
		73: "nieve",
		75: "nieve intensa",
		80: "aguaceros ligeros",
		81: "aguaceros",
		82: "aguaceros intensos",
	}
	if s, ok := codes[code]; ok {
		return s
	}
	return "desconocido"
}
