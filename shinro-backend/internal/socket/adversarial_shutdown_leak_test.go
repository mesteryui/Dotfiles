package socket

import (
	"context"
	"net"
	"os"
	"testing"
	"time"
)

// Adversarial audit: graceful shutdown closes known clients then later closes
// the listener. Connections accepted in that window are never closed and leak.
func TestShutdownClosesLateAcceptedClients(t *testing.T) {
	for attempt := 0; attempt < 100; attempt++ {
		dir := t.TempDir()
		path := dir + "/s.sock"

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

		stopDial := make(chan struct{})
		dialed := make(chan net.Conn, 64)
		go func() {
			for {
				select {
				case <-stopDial:
					return
				default:
				}
				c, err := net.Dial("unix", path)
				if err == nil {
					_, _ = c.Write([]byte("{\"type\":\"hello\"}\n"))
					select {
					case dialed <- c:
					default:
						c.Close()
					}
				}
				time.Sleep(1 * time.Millisecond)
			}
		}()

		// Let some connections establish, then shutdown.
		time.Sleep(10 * time.Millisecond)
		cancel()
		err := <-done

		srv.mu.Lock()
		leaked := len(srv.clients)
		srv.mu.Unlock()

		close(stopDial)
		for {
			select {
			case c := <-dialed:
				c.Close()
			default:
				goto drained
			}
		}
	drained:

		if err != nil {
			t.Fatalf("server shutdown: %v", err)
		}
		if leaked > 0 {
			t.Fatalf("shutdown leaked %d late-accepted clients (attempt %d)", leaked, attempt)
		}
	}
}
