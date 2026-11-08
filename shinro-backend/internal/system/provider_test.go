package system

import (
	"sync"
	"testing"
)

func TestRaceStats(t *testing.T) {
	p := New()
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 100; j++ {
				_, _ = p.Stats()
			}
		}()
	}
	wg.Wait()
}
