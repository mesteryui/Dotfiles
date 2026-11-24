package files

import (
	"fmt"
	"testing"
	"time"
)

// TestCacheEvictaLaEntradaMasAntigua comprueba que, al llenarse el caché de
// búsquedas, se descarta la entrada más antigua y no una arbitraria.
//
// Antes la evicción borraba la primera clave que devolvía el rango del mapa,
// y el orden de iteración de un map en Go es aleatorio: se tiraba una query
// al azar, justo la que el usuario acababa de teclear.
func TestCacheEvictaLaEntradaMasAntigua(t *testing.T) {
	provider := New()

	// Llenar el caché con una entrada más que el tope.
	for i := range maxCacheEntries + 1 {
		query := fmt.Sprintf("q%03d", i)
		provider.addToCache(query, []*Result{{Name: query}}, 10, true)
		// Separar las inserciones para que "at" sea distinto: si no, dos
		// entradas pueden tener la misma marca y el orden sería ambiguo.
		time.Sleep(2 * time.Millisecond)
	}

	provider.cacheMu.RLock()
	defer provider.cacheMu.RUnlock()

	if len(provider.cache) != maxCacheEntries {
		t.Fatalf("esperaba %d entradas en el caché, got %d", maxCacheEntries, len(provider.cache))
	}

	// La más antigua (la primera insertada) debe ser la descartada.
	if _, ok := provider.cache["q000"]; ok {
		t.Fatal("la entrada más antigua no se descartó")
	}

	// Y el resto debe seguir ahí: con la evicción arbitraria anterior,
	// alguna de ellas se habría perdido por el camino.
	for i := 1; i <= maxCacheEntries; i++ {
		query := fmt.Sprintf("q%03d", i)
		if _, ok := provider.cache[query]; !ok {
			t.Fatalf("se perdió la entrada %q, que no era la más antigua", query)
		}
	}
}
