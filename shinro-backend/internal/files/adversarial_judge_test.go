package files

import (
	"os"
	"path/filepath"
	"syscall"
	"testing"
	"time"
	"unsafe"
)

// C1: un overflow de la cola de inotify (IN_Q_OVERFLOW) significa que se
// perdieron eventos. El watcher debe invalidar/notificar para no dejar la caché
// obsoleta hasta el TTL.
func TestWatcherOverflowMustInvalidate(t *testing.T) {
	notified := make(chan struct{}, 4)
	w, err := newWatcher(func() {
		select {
		case notified <- struct{}{}:
		default:
		}
	})
	if err != nil {
		t.Skipf("inotify unavailable: %v", err)
	}
	defer w.close()

	var buf [syscall.SizeofInotifyEvent]byte
	raw := (*syscall.InotifyEvent)(unsafe.Pointer(&buf[0]))
	raw.Wd = -1
	raw.Mask = uint32(syscall.IN_Q_OVERFLOW)

	w.handleEvents(buf[:])

	select {
	case <-notified:
		// ok
	case <-time.After(2 * time.Second):
		t.Fatal("IN_Q_OVERFLOW debe invalidar/notificar; se ignoró y la caché puede quedar obsoleta")
	}
}

// C2: un directorio movido dentro del árbol vigilado (IN_MOVED_TO|IN_ISDIR)
// debe vigilarse recursivamente. Si no, los cambios dentro del subárbol movido
// no se detectan.
func TestWatcherDetectsChangesInsideMovedInDirectory(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	src := filepath.Join(outside, "moved")
	if err := os.Mkdir(src, 0o755); err != nil {
		t.Fatal(err)
	}

	provider := New()
	defer provider.Close()

	// Arranca el watcher.
	if _, err := provider.Search("anything", root, 20); err != nil {
		t.Fatalf("search: %v", err)
	}

	beforeMove := provider.Generation()
	dst := filepath.Join(root, "moved")
	if err := os.Rename(src, dst); err != nil {
		t.Fatal(err)
	}
	if !waitForGeneration(t, provider, beforeMove, 5*time.Second) {
		t.Fatal("no se detectó el movimiento del directorio")
	}

	// Crear un fichero dentro del directorio movido: debe detectarse.
	beforeCreate := provider.Generation()
	if err := os.WriteFile(filepath.Join(dst, "nuevo.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if !waitForGeneration(t, provider, beforeCreate, 5*time.Second) {
		t.Fatal("no se detectó un cambio dentro de un directorio movido al árbol vigilado; el subárbol no quedó vigilado")
	}

	results, err := provider.Search("nuevo", root, 20)
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("se esperaba 1 resultado tras detectar el cambio, got %d", len(results))
	}
}
