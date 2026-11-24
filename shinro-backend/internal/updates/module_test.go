package updates

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type fakeBackend struct {
	id      string
	pkgs    []Package
	err     error
	calls   atomic.Int32
	started chan struct{}
	release chan struct{}
}

func (f *fakeBackend) ID() string { return f.id }

func (f *fakeBackend) Command() []string { return []string{"fake-" + f.id} }

func (f *fakeBackend) Parse(stdout []byte, exit int) ([]Package, error) {
	f.calls.Add(1)
	if f.started != nil {
		select {
		case f.started <- struct{}{}:
		default:
		}
	}
	if f.release != nil {
		<-f.release
	}
	return f.pkgs, f.err
}

type fakeUpdater struct {
	*fakeBackend
	commands [][]string
}

func (f *fakeUpdater) UpdateCommands() [][]string { return f.commands }

type fakeExecutor struct {
	mu      sync.Mutex
	calls   [][]string
	outputs map[string]Output
	errs    map[string]error
}

func newFakeExecutor() *fakeExecutor {
	return &fakeExecutor{
		outputs: make(map[string]Output),
		errs:    make(map[string]error),
	}
}

func (f *fakeExecutor) Run(ctx context.Context, argv []string) (Output, error) {
	f.mu.Lock()
	f.calls = append(f.calls, append([]string(nil), argv...))
	out := f.outputs[argv[0]]
	err := f.errs[argv[0]]
	f.mu.Unlock()
	return out, err
}

func (f *fakeExecutor) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.calls)
}

func (f *fakeExecutor) last() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.calls) == 0 {
		return nil
	}
	return f.calls[len(f.calls)-1]
}

func TestModuleCheck(t *testing.T) {
	fb := &fakeBackend{
		id: "pacman",
		pkgs: []Package{
			{Name: "foo", Old: "1.0", New: "1.1", Backend: "pacman"},
			{Name: "bar", Old: "2.0", New: "2.1", Backend: "pacman"},
		},
	}
	m := New([]Backend{fb}, newFakeExecutor(), func() bool { return true })

	state := m.Check(context.Background())
	if state.Count != 2 || len(state.Packages) != 2 {
		t.Fatalf("estado = %+v", state)
	}
	if state.CheckedAt == 0 {
		t.Fatal("checked_at no se actualizó")
	}
	if state.Checking {
		t.Fatal("checking debería ser false al terminar")
	}
	if len(state.Errors) != 0 {
		t.Fatalf("errores inesperados: %+v", state.Errors)
	}
}

func TestModuleOfflineDoesNotRun(t *testing.T) {
	fb := &fakeBackend{id: "pacman"}
	ex := newFakeExecutor()
	m := New([]Backend{fb}, ex, func() bool { return false })

	state := m.Check(context.Background())
	if state.CheckedAt != 0 || state.Count != 0 {
		t.Fatalf("estado sin red = %+v", state)
	}
	if fb.calls.Load() != 0 || ex.count() != 0 {
		t.Fatal("sin red no se debe ejecutar ningún backend")
	}
}

func TestModulePartialFailure(t *testing.T) {
	ok := &fakeBackend{
		id:   "pacman",
		pkgs: []Package{{Name: "foo", New: "1.1", Backend: "pacman"}},
	}
	bad := &fakeBackend{id: "aur", err: fmt.Errorf("falló la red")}
	m := New([]Backend{ok, bad}, newFakeExecutor(), func() bool { return true })
	m.Configure(Config{Backends: []string{"all"}})

	state := m.Check(context.Background())
	if len(state.Packages) != 1 || state.Packages[0].Name != "foo" {
		t.Fatalf("los paquetes del backend bueno se perdieron: %+v", state.Packages)
	}
	if len(state.Errors) != 1 || state.Errors[0].Backend != "aur" {
		t.Fatalf("errores = %+v", state.Errors)
	}
}

func TestModuleSingleflight(t *testing.T) {
	fb := &fakeBackend{
		id:      "pacman",
		pkgs:    []Package{{Name: "foo", New: "1.1", Backend: "pacman"}},
		started: make(chan struct{}, 1),
		release: make(chan struct{}),
	}
	m := New([]Backend{fb}, newFakeExecutor(), func() bool { return true })

	var wg sync.WaitGroup
	for range 4 {
		wg.Go(func() {
			m.Check(context.Background())
		})
	}

	// Esperar a que la primera comprobación esté dentro del backend y
	// soltarla: las demás deben compartir el mismo resultado.
	select {
	case <-fb.started:
	case <-time.After(time.Second):
		t.Fatal("la comprobación no llegó al backend")
	}
	// Dar tiempo a que las demás goroutines lleguen al wait del singleflight
	// antes de soltar la primera comprobación.
	time.Sleep(50 * time.Millisecond)
	close(fb.release)
	wg.Wait()

	if got := fb.calls.Load(); got != 1 {
		t.Fatalf("el backend se ejecutó %d veces, quiero 1", got)
	}
}

func TestModuleUpdate(t *testing.T) {
	up := &fakeUpdater{
		fakeBackend: &fakeBackend{
			id:   "pacman",
			pkgs: []Package{{Name: "foo", New: "1.1", Backend: "pacman"}},
		},
		commands: [][]string{{"update-cmd"}},
	}
	ex := newFakeExecutor()
	m := New([]Backend{up}, ex, func() bool { return true })

	state := m.Update(context.Background())
	if state.Updating {
		t.Fatal("updating debería ser false al terminar")
	}
	if state.LastUpdateAt == 0 {
		t.Fatal("last_update_at no se actualizó")
	}
	if state.Count != 1 {
		t.Fatalf("la comprobación posterior no refrescó el contador: %+v", state)
	}

	found := false
	for _, call := range ex.calls {
		if len(call) == 1 && call[0] == "update-cmd" {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("no se ejecutó el comando de actualización: %v", ex.calls)
	}
}

func TestModuleUpdateWithoutUpdater(t *testing.T) {
	fb := &fakeBackend{id: "pacman"}
	m := New([]Backend{fb}, newFakeExecutor(), func() bool { return true })

	state := m.Update(context.Background())
	if state.LastUpdateAt == 0 {
		t.Fatal("last_update_at no se actualizó")
	}
	if len(state.Errors) != 1 || state.Errors[0].Backend != "updates" {
		t.Fatalf("errores = %+v", state.Errors)
	}
}

func TestModuleUpdateOffline(t *testing.T) {
	fb := &fakeBackend{id: "pacman"}
	ex := newFakeExecutor()
	m := New([]Backend{fb}, ex, func() bool { return false })

	state := m.Update(context.Background())
	if len(state.Errors) != 1 || state.Errors[0].Backend != "network" {
		t.Fatalf("errores = %+v", state.Errors)
	}
	if ex.count() != 0 {
		t.Fatal("sin red no se debe ejecutar la actualización")
	}
}

func TestModuleConfigureResetsState(t *testing.T) {
	first := &fakeBackend{
		id:   "pacman",
		pkgs: []Package{{Name: "foo", New: "1.1", Backend: "pacman"}},
	}
	second := &fakeBackend{
		id:   "aur",
		pkgs: []Package{{Name: "bar", New: "2.1", Backend: "aur"}},
	}
	m := New([]Backend{first, second}, newFakeExecutor(), func() bool { return true })
	m.Configure(Config{Backends: []string{"pacman"}})
	if state := m.Check(context.Background()); state.Count != 1 {
		t.Fatalf("estado inicial = %+v", state)
	}

	m.Configure(Config{Backends: []string{"aur"}})
	state := m.Snapshot()
	if state.Count != 0 || len(state.Packages) != 0 || state.CheckedAt != 0 {
		t.Fatalf("el cambio de backend no limpió el estado: %+v", state)
	}
	if !sameStrings(state.Backends, []string{"aur"}) {
		t.Fatalf("backends = %v", state.Backends)
	}
}

func TestModuleBroadcast(t *testing.T) {
	fb := &fakeBackend{id: "pacman"}
	m := New([]Backend{fb}, newFakeExecutor(), func() bool { return true })

	var calls atomic.Int32
	m.SetBroadcast(func() { calls.Add(1) })
	m.Check(context.Background())
	if calls.Load() < 2 {
		t.Fatalf("broadcast llamado %d veces, quiero al menos 2", calls.Load())
	}
}

func TestModuleConfigCommand(t *testing.T) {
	ex := newFakeExecutor()
	ex.outputs["mi-gestor"] = Output{Stdout: []byte("foo 1.0 -> 1.1\n"), Exit: 0}
	m := New(nil, ex, func() bool { return true })
	m.Configure(Config{
		Backends: []string{"all"},
		Command:  &CommandSpec{Argv: []string{"mi-gestor"}, Format: "lines-versions"},
	})

	state := m.Check(context.Background())
	if state.Count != 1 || state.Packages[0].Backend != "command" {
		t.Fatalf("backend command no funcionó: %+v", state)
	}
}
