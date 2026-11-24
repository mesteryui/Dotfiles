package updates

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

type blockingExecutor struct {
	blockCmd string
	started  chan struct{}
	release  chan struct{}
}

func (b *blockingExecutor) Run(ctx context.Context, argv []string) (Output, error) {
	if len(argv) > 0 && argv[0] == b.blockCmd {
		if b.started != nil {
			select {
			case b.started <- struct{}{}:
			default:
			}
		}
		if b.release != nil {
			<-b.release
		}
	}
	return Output{}, nil
}

// D1: la exclusión mutua check/update debe respetarse incluso si el contexto
// del caller se cancela. waitCtx hoy devuelve en ctx.Done() y el caller
// procede, permitiendo ejecutar check y update concurrentemente.
func TestCheckRespectsUpdateExclusionWhenContextCancelled(t *testing.T) {
	updateStarted := make(chan struct{}, 1)
	updateRelease := make(chan struct{})
	up := &fakeUpdater{
		fakeBackend: &fakeBackend{id: "pacman"},
		commands:    [][]string{{"update-cmd"}},
	}
	ex := &blockingExecutor{blockCmd: "update-cmd", started: updateStarted, release: updateRelease}

	checkStarted := make(chan struct{}, 1)
	checkRelease := make(chan struct{})
	checker := &fakeBackend{id: "aur", started: checkStarted, release: checkRelease}

	m := New([]Backend{up, checker}, ex, func() bool { return true })
	m.Configure(Config{Backends: []string{"all"}})

	ctx, cancel := context.WithCancel(context.Background())
	updateDone := make(chan struct{})
	go func() {
		_ = m.Update(ctx)
		close(updateDone)
	}()

	select {
	case <-updateStarted:
	case <-time.After(2 * time.Second):
		t.Fatal("update no arrancó")
	}

	cancel() // cancela el contexto del caller mientras update sigue en curso

	checkDone := make(chan struct{})
	go func() {
		_ = m.Check(ctx)
		close(checkDone)
	}()

	select {
	case <-checkStarted:
		close(checkRelease)
		close(updateRelease)
		<-updateDone
		<-checkDone
		t.Fatal("Check se ejecutó concurrentemente con Update tras cancelar el contexto; waitCtx rompió la exclusión mutua")
	case <-time.After(350 * time.Millisecond):
		// bien: Check sigue esperando a que termine Update
	}

	close(updateRelease)

	// El refresh post-update y/o el Check explícito pueden ejecutar el backend
	// de comprobación; hay que soltarlo para que el test no se bloquee.
	go func() {
		for {
			select {
			case <-checkStarted:
				// drenar señales extra
			case <-checkDone:
				return
			case <-time.After(5 * time.Second):
				return
			}
		}
	}()
	// Cerrar release una vez cuando llegue la primera señal o tras timeout.
	go func() {
		select {
		case <-checkStarted:
			close(checkRelease)
		case <-checkDone:
			close(checkRelease)
		case <-time.After(2 * time.Second):
			close(checkRelease)
		}
	}()

	select {
	case <-updateDone:
	case <-time.After(5 * time.Second):
		t.Fatal("update no terminó")
	}
	select {
	case <-checkDone:
	case <-time.After(5 * time.Second):
		t.Fatal("check no terminó")
	}
}

var _ = atomic.Int32{} // evitar import no usado si se ajusta el test
