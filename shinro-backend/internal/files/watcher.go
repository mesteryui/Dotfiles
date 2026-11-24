package files

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"unsafe"

	"shinro-backend/internal/logger"
)

// watcherMask: solo los eventos que cambian el CONJUNTO de ficheros
// (crear, borrar, mover). Los cambios de CONTENIDO (IN_MODIFY) no alteran
// los resultados de una búsqueda, así que se ignoran: de lo contrario una
// compilación o un log en rotación provocarían rescaneos del disco.
const watcherMask = syscall.IN_CREATE | syscall.IN_DELETE |
	syscall.IN_MOVED_FROM | syscall.IN_MOVED_TO |
	syscall.IN_DELETE_SELF | syscall.IN_MOVE_SELF |
	syscall.IN_EXCL_UNLINK

// watcher vigila cambios en el árbol de directorios usando inotify.
//
// Se vigilan exactamente los directorios que las búsquedas recorren (los
// no ocultos, hasta la misma profundidad máxima): así lo que el buscador ve
// y lo que el vigilante cubre coinciden, sin vigilar directorios que nadie
// busca (node_modules, .cache, ...).
//
// No es polling: el backend se entera de los cambios por evento.
//
// inotify es específico de Linux, y el backend es Linux-only por diseño (lee
// /proc y /sys, habla D-Bus con NetworkManager y habla el protocolo Wayland
// directamente): no hay variante para otras plataformas.
type watcher struct {
	fd   int
	epfd int

	mu        sync.Mutex
	watches   map[int]string // wd → ruta
	paths     map[string]int // ruta → wd
	closed    bool
	started   bool
	rootDepth int

	// fdClosed evita cerrar dos veces el descriptor de inotify.
	fdClosed bool

	notify func()
}

// newWatcher crea un watcher de inotify y lo registra en una instancia de epoll.
func newWatcher(notify func()) (*watcher, error) {
	fd, err := syscall.InotifyInit1(syscall.IN_NONBLOCK | syscall.IN_CLOEXEC)
	if err != nil {
		return nil, err
	}
	epfd, err := syscall.EpollCreate1(syscall.EPOLL_CLOEXEC)
	if err != nil {
		_ = syscall.Close(fd)
		return nil, err
	}
	ev := syscall.EpollEvent{
		Events: syscall.EPOLLIN,
		Fd:     int32(fd),
	}
	if err := syscall.EpollCtl(epfd, syscall.EPOLL_CTL_ADD, fd, &ev); err != nil {
		_ = syscall.Close(epfd)
		_ = syscall.Close(fd)
		return nil, err
	}
	return &watcher{
		fd:      fd,
		epfd:    epfd,
		watches: make(map[int]string),
		paths:   make(map[string]int),
		notify:  notify,
	}, nil
}

// watchTree vigila root y todos sus subdirectorios visibles (mismas reglas
// de exclusión y profundidad que la búsqueda).
func (w *watcher) watchTree(root string) {
	rootDepth := strings.Count(root, string(filepath.Separator))
	w.mu.Lock()
	w.rootDepth = rootDepth
	w.mu.Unlock()
	vistos := 0

	_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			logger.Warn("files: error recorriendo el árbol vigilado", "path", path, "error", err)
			return nil
		}
		if !d.IsDir() {
			return nil
		}
		if path != root {
			if isExcludedDir(d.Name()) {
				return fs.SkipDir
			}
			depth := strings.Count(path, string(filepath.Separator)) - rootDepth
			if depth > maxDepth {
				return fs.SkipDir
			}
		}
		if w.addWatch(path) {
			vistos++
		}
		return nil
	})

	logger.Info("files: directorios vigilados", "root", root, "total", vistos)
}

// addWatch vigila un directorio. Es idempotente.
func (w *watcher) addWatch(path string) bool {
	w.mu.Lock()
	if w.closed {
		w.mu.Unlock()
		return false
	}
	if _, ok := w.paths[path]; ok {
		w.mu.Unlock()
		return true
	}
	if len(w.watches) >= maxWatches {
		// Tope alcanzado: se sigue con los directorios ya vigilados.
		w.mu.Unlock()
		return false
	}
	w.mu.Unlock()

	wd, err := syscall.InotifyAddWatch(w.fd, path, watcherMask)
	if err != nil {
		logger.Warn("files: no se pudo vigilar el directorio", "path", path, "error", err)
		return false
	}

	w.mu.Lock()
	if w.closed {
		w.mu.Unlock()
		return false
	}
	// inotify reutiliza el mismo wd para la misma ruta, pero si el
	// directorio se borró y se recreó puede venir otro: se limpia el viejo.
	if old, ok := w.paths[path]; ok && old != wd {
		delete(w.watches, old)
	}
	w.watches[wd] = path
	w.paths[path] = wd
	w.mu.Unlock()
	return true
}

// addSubtree vigila un directorio nuevo y sus subdirectorios.
func (w *watcher) addSubtree(parent, name string) {
	if parent == "" || name == "" {
		return
	}
	path := filepath.Join(parent, name)

	w.mu.Lock()
	rootDepth := w.rootDepth
	w.mu.Unlock()

	pathDepth := strings.Count(path, string(filepath.Separator)) - rootDepth
	if pathDepth > maxDepth {
		return
	}

	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		return
	}
	w.addWatch(path)
	_ = filepath.WalkDir(path, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if !d.IsDir() {
			return nil
		}
		if p != path && isExcludedDir(d.Name()) {
			return fs.SkipDir
		}
		depth := strings.Count(p, string(filepath.Separator)) - rootDepth
		if depth > maxDepth {
			return fs.SkipDir
		}
		w.addWatch(p)
		return nil
	})
}

// pathOf devuelve la ruta vigilada por un wd.
func (w *watcher) pathOf(wd int) string {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.watches[wd]
}

// removeWatch olvida un watch (el directorio ya no existe).
func (w *watcher) removeWatch(wd int) {
	w.mu.Lock()
	path, ok := w.watches[wd]
	if ok {
		delete(w.watches, wd)
		delete(w.paths, path)
	}
	w.mu.Unlock()
}

// run lee los eventos hasta que se cierra el watcher.
//
// El descriptor de inotify lo cierra este bucle al salir, nunca close(): si
// se cerrara desde fuera, un select() que ya estuviese esperando sobre ese
// descriptor seguiría esperando (en Linux, cerrar un fd no despierta a
// select()) y el número de descriptor podría ser reutilizado por otro
// open(), con lo que la lectura leería del descriptor equivocado.
func (w *watcher) run() {
	buf := make([]byte, 64*1024)

	w.mu.Lock()
	w.started = true
	w.mu.Unlock()
	defer w.closeFD()

	events := make([]syscall.EpollEvent, 1)

	for {
		if w.isClosed() {
			return
		}

		// Esperar eventos con epoll: no tiene el límite histórico de 1024 descriptores de select.
		n, err := syscall.EpollWait(w.epfd, events, 1000)
		if err != nil {
			if err == syscall.EINTR {
				continue
			}
			return
		}
		if n <= 0 {
			continue // timeout: volver a la cabecera del bucle para comprobar w.isClosed()
		}

		for {
			n, err := syscall.Read(w.fd, buf)
			if err != nil {
				if err == syscall.EAGAIN || err == syscall.EWOULDBLOCK {
					break
				}
				if err == syscall.EINTR {
					continue
				}
				return
			}
			if n <= 0 {
				break
			}
			w.handleEvents(buf[:n])
		}
	}
}

// handleEvents procesa el bloque de eventos leído de inotify.
func (w *watcher) handleEvents(buf []byte) {
	changed := false
	offset := 0

	for offset+syscall.SizeofInotifyEvent <= len(buf) {
		raw := (*syscall.InotifyEvent)(unsafe.Pointer(&buf[offset]))
		mask := raw.Mask
		nameLen := int(raw.Len)
		name := ""

		if nameLen > 0 {
			start := offset + syscall.SizeofInotifyEvent
			end := start + nameLen
			if end > len(buf) {
				break
			}
			rawName := buf[start:end]
			for i, b := range rawName {
				if b == 0 {
					rawName = rawName[:i]
					break
				}
			}
			name = string(rawName)
		}

		wd := int(raw.Wd)

		switch {
		case mask&syscall.IN_Q_OVERFLOW != 0:
			// Se perdieron eventos: forzar invalidación de caché.
			changed = true

		case mask&syscall.IN_IGNORED != 0:
			// El directorio vigilado ya no existe.
			w.removeWatch(wd)

		case mask&(syscall.IN_CREATE|syscall.IN_DELETE|syscall.IN_MOVED_FROM|syscall.IN_MOVED_TO) != 0:
			changed = true
			// Un directorio nuevo hay que vigilarlo (y a su subárbol),
			// o sus cambios pasarían inadvertidos. Un moved-in (IN_MOVED_TO)
			// también necesita watch recursivo.
			if mask&(syscall.IN_CREATE|syscall.IN_MOVED_TO) != 0 && mask&syscall.IN_ISDIR != 0 {
				w.addSubtree(w.pathOf(wd), name)
			}

		case mask&(syscall.IN_DELETE_SELF|syscall.IN_MOVE_SELF) != 0:
			changed = true
		}

		offset += syscall.SizeofInotifyEvent + nameLen
	}

	if changed && w.notify != nil {
		w.notify()
	}
}

// isClosed indica si el watcher ya se cerró.
func (w *watcher) isClosed() bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.closed
}

// close pide al watcher que termine.
//
// NO cierra el descriptor de inotify: el bucle run() puede estar bloqueado
// en select() sobre ese descriptor, y cerrarlo desde aquí dejaría el select
// esperando sobre un número que otro open() podría reutilizar (y la lectura
// leería del descriptor equivocado). El descriptor lo cierra el propio bucle
// al salir (ver closeFD).
//
// El bucle comprueba el flag en cada iteración y el select() tiene un
// timeout de un segundo, así que termina en cuanto como mucho un segundo
// después del cierre.
func (w *watcher) close() {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.closed {
		return
	}
	w.closed = true
	w.watches = make(map[int]string)
	w.paths = make(map[string]int)

	// Si el bucle nunca llegó a arrancar, no hay nadie que cierre el
	// descriptor: cerrarlo aquí.
	if !w.started {
		w.closeFDLocked()
	}
}

// closeFD cierra el descriptor de inotify (una sola vez).
func (w *watcher) closeFD() {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.closeFDLocked()
}

// closeFDLocked cierra el descriptor. Debe llamarse con el lock cogido.
func (w *watcher) closeFDLocked() {
	if w.fdClosed {
		return
	}
	w.fdClosed = true
	if w.epfd >= 0 {
		_ = syscall.Close(w.epfd)
	}
	_ = syscall.Close(w.fd)
}
