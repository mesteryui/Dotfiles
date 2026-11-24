package socket

import (
	"context"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Adversarial audit: graceful shutdown must not unlink a replacement daemon's
// socket. It observes the real Server.Start shutdown path.
func TestShutdownDoesNotUnlinkReplacedSocket(t *testing.T) {
	const attempts = 200
	sawReplaced := false

	for attempt := 0; attempt < attempts; attempt++ {
		dir := t.TempDir()
		path := filepath.Join(dir, "s.sock")

		ctx, cancel := context.WithCancel(context.Background())
		srv := NewServer(NewRegistry(), nil)
		srv.path = path

		done := make(chan error, 1)
		go func() { done <- srv.Start(ctx) }()

		for i := 0; i < 300; i++ {
			if _, err := os.Stat(path); err == nil {
				break
			}
			time.Sleep(2 * time.Millisecond)
		}

		type result struct {
			replaced bool
			unlinked bool
		}
		resCh := make(chan result, 1)
		go func() {
			for {
				lock, err := AcquireLock(path)
				if err != nil {
					select {
					case <-done:
						resCh <- result{}
						return
					default:
					}
					time.Sleep(200 * time.Microsecond)
					continue
				}
				_ = os.Remove(path)
				ln, err := net.Listen("unix", path)
				if err != nil {
					lock.Close()
					resCh <- result{}
					return
				}
				unlinked := false
				deadline := time.Now().Add(200 * time.Millisecond)
				for time.Now().Before(deadline) {
					if _, err := os.Stat(path); err != nil {
						unlinked = true
						break
					}
					time.Sleep(time.Millisecond)
				}
				ln.Close()
				lock.Close()
				resCh <- result{replaced: true, unlinked: unlinked}
				return
			}
		}()

		cancel()
		if err := <-done; err != nil {
			t.Fatalf("server shutdown: %v", err)
		}
		r := <-resCh
		if r.replaced {
			sawReplaced = true
			if r.unlinked {
				t.Fatalf("replacement socket was unlinked by old shutdown (attempt %d)", attempt)
			}
		}
	}

	if !sawReplaced {
		// The race window is timing-dependent; not observing it is not a pass
		// for the old bug, but with the fix there is no window to observe.
		t.Logf("no lock handoff interleaving observed in %d attempts", attempts)
	}
}
