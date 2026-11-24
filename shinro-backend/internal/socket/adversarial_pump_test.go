package socket

import (
	"encoding/json"
	"net"
	"sync"
	"testing"
	"time"
)

type dummyPumpModule struct{ name string }

func (m *dummyPumpModule) Name() string { return m.name }
func (m *dummyPumpModule) HandleHello(*client, map[string]json.RawMessage) {
}
func (m *dummyPumpModule) HandleGet(*client, map[string]json.RawMessage) error { return nil }
func (m *dummyPumpModule) SendUpdate(*client) error                           { return nil }

// Adversarial audit: startPump does Add() after checking stopping, but shutdown
// can enter Wait() concurrently, causing WaitGroup misuse.
func TestStartPumpWaitGroupRace(t *testing.T) {
	for i := 0; i < 200; i++ {
		reg := NewRegistry()
		m := &dummyPumpModule{name: "dummy"}
		reg.Register(m)
		s := NewServer(reg, nil)
		s.path = t.TempDir() + "/s.sock"

		c1, c2 := net.Pipe()
		c := &client{
			conn:         c1,
			send:         make(chan []byte, 8),
			done:         make(chan struct{}),
			server:       s,
			subs:         map[string]bool{"dummy": true},
			modIntervals: map[string]int{"dummy": 0},
			modWakes:     map[string]chan struct{}{"dummy": make(chan struct{}, 1)},
		}

		var gate sync.WaitGroup
		gate.Add(2)
		go func() {
			gate.Done()
			gate.Wait()
			s.shutdownMu.Lock()
			s.stopping.Store(true)
			s.shutdownMu.Unlock()
			s.pumpsWG.Wait()
		}()
		go func() {
			gate.Done()
			gate.Wait()
			s.startPump(m, c)
		}()

		time.Sleep(5 * time.Millisecond)
		c.close()
		c2.Close()
	}
}
