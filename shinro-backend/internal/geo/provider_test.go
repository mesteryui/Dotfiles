package geo

import (
	"sync"
	"testing"
)

func TestRaceManualLocation(t *testing.T) {
	p := New()
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		for i := 0; i < 500; i++ {
			p.SetManual("Vigo,ES")
		}
	}()
	go func() {
		defer wg.Done()
		for i := 0; i < 500; i++ {
			_, _ = p.Location()
		}
	}()
	wg.Wait()
}
