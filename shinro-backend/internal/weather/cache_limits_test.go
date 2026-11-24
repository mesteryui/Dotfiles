package weather

import (
	"fmt"
	"testing"
	"time"
)

// TestLasCachesNoCrecenSinLimite comprueba que las cachés del proveedor no
// crecen sin límite.
//
// El daemon es de larga vida: si alguien teclea muchas ciudades distintas,
// cada una dejaba su previsión (10-20 KB) guardada para siempre. Con el tope,
// solo se conservan las últimas.
func TestLasCachesNoCrecenSinLimite(t *testing.T) {
	w := New()

	// Llenar la caché de previsión con muchas coordenadas distintas.
	for i := range maxWeatherCacheEntries * 3 {
		lat := float64(i) * 0.01
		key := fmt.Sprintf("%.4f,%.4f", lat, lat)
		w.fcMu.Lock()
		w.fcCache[key] = forecastCacheEntry{
			snap: Snapshot{Current: Current{Temperature2M: lat}},
			at:   time.Now(),
		}
		w.fcMu.Unlock()
	}
	w.fcMu.Lock()
	pruneCache(w.fcCache, func(e forecastCacheEntry) time.Time { return e.at })
	tam := len(w.fcCache)
	w.fcMu.Unlock()

	if tam > maxWeatherCacheEntries {
		t.Fatalf("la caché de previsión tiene %d entradas, el tope es %d", tam, maxWeatherCacheEntries)
	}
	if tam == 0 {
		t.Fatal("la caché se vació por completo")
	}
}

// TestPruneCacheDescartaLaMasAntigua comprueba que el descarte es por
// antigüedad y no arbitrario (el orden de iteración de un map es aleatorio).
func TestPruneCacheDescartaLaMasAntigua(t *testing.T) {
	m := map[string]cachedSnapshot{}
	base := time.Now()
	total := maxWeatherCacheEntries + 2
	for i := range total {
		m[fmt.Sprintf("q%d", i)] = cachedSnapshot{
			at: base.Add(time.Duration(i) * time.Second),
		}
	}
	pruneCache(m, func(e cachedSnapshot) time.Time { return e.at })

	if len(m) != maxWeatherCacheEntries {
		t.Fatalf("esperaba %d entradas, got %d", maxWeatherCacheEntries, len(m))
	}
	// Las dos más antiguas deben ser las descartadas.
	for i := range 2 {
		if _, ok := m[fmt.Sprintf("q%d", i)]; ok {
			t.Fatalf("la entrada q%d (de las más antiguas) no se descartó", i)
		}
	}
	// Y el resto debe seguir ahí.
	for i := 2; i < total; i++ {
		if _, ok := m[fmt.Sprintf("q%d", i)]; !ok {
			t.Fatalf("se perdió la entrada q%d, que no era de las más antiguas", i)
		}
	}
}
