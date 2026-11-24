package files

import (
	"context"
	"errors"
	"testing"
	"time"
)

// Adversarial audit: empty query search bypasses the provider semaphore,
// allowing unbounded concurrent full-HOME walks.
func TestSearchEmptyRespectsSemaphore(t *testing.T) {
	p := New()
	// Fill the semaphore so any search that respects it must block.
	for i := 0; i < cap(p.sem); i++ {
		p.sem <- struct{}{}
	}
	t.Cleanup(func() {
		for i := 0; i < cap(p.sem); i++ {
			<-p.sem
		}
		p.Close()
	})

	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()

	_, err := p.SearchContext(ctx, "", t.TempDir(), 10)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected deadline exceeded while semaphore full, got err=%v", err)
	}
}
