package system

import (
	"sync"
	"testing"
)

func TestRaceStats(t *testing.T) {
	p := New()
	var wg sync.WaitGroup
	for range 4 {
		wg.Go(func() {
			for range 100 {
				_, _ = p.Stats()
			}
		})
	}
	wg.Wait()
}

func TestBatteryTimeToEmptyCalculation(t *testing.T) {
	// 50 Wh = 50,000,000 µWh, 10 W = 10,000,000 µW -> 5 horas = 300 minutos
	now := int64(50000000)
	power := int64(10000000)
	minutos := int((float64(now) / float64(power)) * 60)
	if minutos != 300 {
		t.Fatalf("esperaba 300 minutos, obtenido %d", minutos)
	}
}
