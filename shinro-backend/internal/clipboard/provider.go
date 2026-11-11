// Package clipboard provee un portapapeles Wayland con historial persistente,
// siguiendo el modelo de Ryoku: deduplicación por hash FNV, thumbnails de
// imagen, entradas starred, auto-prune semanal y límites de tamaño.
// Habla el protocolo Wayland directamente (zwlr_data_control_manager_v1):
// lee la selección, la posee mientras el backend vive y recibe un evento por
// cada copia, sin wl-copy/wl-paste ni polling. Si el compositor no ofrece
// wlr-data-control, cae a los procesos wl-clipboard como respaldo.
package clipboard

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"hash/fnv"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	"image/png"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"shinro-backend/internal/logger"
)

const (
	clipMaxEntries      = 100       // historial máximo
	clipMaxEntryBytes   = 10 << 20  // 10 MiB por entrada
	clipMaxStarredBytes = 100 << 20 // 100 MiB total para starred
	clipTextPreviewLen  = 200       // preview en caracteres
	clipThumbnailSize   = 512       // bounding box del thumbnail en px

	clipCmdTimeout = 5 * time.Second // límite para leer/escribir el portapapeles
)

// Entry representa una entrada del historial de portapapeles.
type Entry struct {
	ID         uint64 `json:"id"`
	Kind       string `json:"kind"` // "text" | "image" | "binary"
	Mime       string `json:"mime"`
	Size       int    `json:"size"`
	Preview    string `json:"preview,omitempty"`
	ThumbPath  string `json:"thumb,omitempty"`
	ThumbW     int    `json:"thumbW,omitempty"`
	ThumbH     int    `json:"thumbH,omitempty"`
	W          int    `json:"w,omitempty"`
	H          int    `json:"h,omitempty"`
	Starred    bool   `json:"starred"`
	Hash       uint64 `json:"hash"`
	TS         int64  `json:"ts"` // unix nano
	thumbBytes int    `json:"-"`  // tamaño del thumbnail en disco (no serializado)
}

// Provider gestiona el portapapeles y su historial persistente.
type Provider struct {
	mu       sync.Mutex
	entries  []*Entry // newest at front
	nextID   uint64
	cacheDir string // thumbnails
	stateDir string // persisted index + payloads
	dataDir  string // payload bytes keyed by hash

	// watch externos
	watchMu          sync.Mutex
	watchStartMu     sync.Mutex // serializa StartWatch/StopWatch (Add/Wait)
	watchRunning     bool
	watchCancel      context.CancelFunc
	watchWG          sync.WaitGroup
	lastExternalHash uint64 // último hash visto de fuente externa para evitar eco

	// Acceso nativo a Wayland (zwlr_data_control_manager_v1). nil mientras
	// no hay conexión: en ese caso se usa el fallback wl-copy/wl-paste.
	wlMu sync.Mutex
	wl   *wlClient

	// onChange se invoca (sin locks del proveedor) cada vez que el historial
	// cambia, para que el módulo socket empuje el listado a los clientes.
	onChangeMu sync.RWMutex
	onChange   func()
}

// New crea un proveedor de portapapeles. stateDir vacío desactiva persistencia.
// Carga el historial persistido si existe, para sobrevivir a reinicios.
func New(stateDir string) *Provider {
	cacheDir := ""
	dataDir := ""
	if stateDir != "" {
		cacheDir = filepath.Join(stateDir, "cache")
		dataDir = filepath.Join(stateDir, "data")
		_ = os.MkdirAll(cacheDir, 0o700)
		_ = os.MkdirAll(stateDir, 0o700)
		_ = os.MkdirAll(dataDir, 0o700)
	}
	provider := &Provider{
		entries:  make([]*Entry, 0),
		nextID:   1,
		cacheDir: cacheDir,
		stateDir: stateDir,
		dataDir:  dataDir,
	}
	if stateDir != "" {
		provider.load()
	}
	return provider
}

// SetOnChange registra una función que se llama tras cada mutación del
// historial (nuevo contenido, borrado, starred...). La llamada se hace sin
// los locks del proveedor, así que puede consultar List() con seguridad.
func (provider *Provider) SetOnChange(fn func()) {
	provider.onChangeMu.Lock()
	provider.onChange = fn
	provider.onChangeMu.Unlock()
}

// notifyChanged avisa al consumidor sin retener provider.mu.
func (provider *Provider) notifyChanged() {
	provider.onChangeMu.RLock()
	fn := provider.onChange
	provider.onChangeMu.RUnlock()
	if fn != nil {
		fn()
	}
}

// markExternalHash registra el hash de contenido que acabamos de poner en el
// portapapeles para que el watcher no lo vuelva a ingerir como cambio externo.
func (provider *Provider) markExternalHash(h uint64) {
	provider.watchMu.Lock()
	provider.lastExternalHash = h
	provider.watchMu.Unlock()
}

// state paths
func (provider *Provider) indexPath() string {
	if provider.stateDir == "" {
		return ""
	}
	return filepath.Join(provider.stateDir, "index.json")
}

func (provider *Provider) dataPath(hash uint64) string {
	if provider.dataDir == "" {
		return ""
	}
	return filepath.Join(provider.dataDir, fmt.Sprintf("%016x.bin", hash))
}

// clipHash keys dedup using FNV-1a over raw bytes.
func clipHash(data []byte) uint64 {
	h := fnv.New64a()
	_, _ = h.Write(data)
	return h.Sum64()
}

// truncateBytesRunes trunca a n runes respetando UTF-8.
func truncateBytesRunes(data []byte, n int) string {
	if n <= 0 {
		return ""
	}
	end := 0
	for range n {
		if end == len(data) {
			return string(data)
		}
		_, size := utf8.DecodeRune(data[end:])
		end += size
	}
	if end == len(data) {
		return string(data)
	}
	if utf8.Valid(data[:end]) {
		return string(data[:end])
	}
	return string([]rune(string(data[:end])))
}

// classifyClip deriva el tipo y preview de los bytes según su mime.
func classifyClip(mime string, data []byte) (kind, preview string, thumb []byte, thumbWidth, thumbHeight, width, height int) {
	switch {
	case strings.HasPrefix(mime, "text/"):
		return "text", truncateBytesRunes(data, clipTextPreviewLen), nil, 0, 0, 0, 0
	case strings.HasPrefix(mime, "image/"):
		if t, thumbWidth, thumbHeight, sourceWidth, sourceHeight, ok := thumbnailPNG(data, clipThumbnailSize); ok {
			return "image", "", t, thumbWidth, thumbHeight, sourceWidth, sourceHeight
		}
		return "binary", "", nil, 0, 0, 0, 0
	default:
		return "binary", "", nil, 0, 0, 0, 0
	}
}

// thumbnailPNG decodifica una imagen y escala (aspect preservado, sin upscale)
// a un PNG que cabe en max*max.
func thumbnailPNG(data []byte, max int) (encoded []byte, thumbWidth, thumbHeight, sourceWidth, sourceHeight int, ok bool) {
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, 0, 0, 0, 0, false
	}
	b := img.Bounds()
	sw, sh := b.Dx(), b.Dy()
	if sw <= 0 || sh <= 0 {
		return nil, 0, 0, 0, 0, false
	}
	nw, nh := fitBox(sw, sh, max)
	dst := image.NewRGBA(image.Rect(0, 0, nw, nh))
	for y := range nh {
		sy := y * sh / nh
		for x := range nw {
			sx := x * sw / nw
			dst.Set(x, y, img.At(b.Min.X+sx, b.Min.Y+sy))
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, dst); err != nil {
		return nil, 0, 0, 0, 0, false
	}
	return buf.Bytes(), nw, nh, sw, sh, true
}

// fitBox devuelve el mayor w*h que cabe en max*max sin agrandar.
func fitBox(w, h, max int) (int, int) {
	if w <= max && h <= max {
		return w, h
	}
	if w >= h {
		nh := max * h / w
		if nh < 1 {
			nh = 1
		}
		return max, nh
	}
	nw := max * w / h
	if nw < 1 {
		nw = 1
	}
	return nw, max
}

// buildEntry convierte bytes en una entrada, persiste thumbnail si hay uno.
func (provider *Provider) buildEntry(mime string, data []byte) *Entry {
	kind, preview, thumb, thumbWidth, thumbHeight, width, height := classifyClip(mime, data)
	entry := &Entry{
		Kind:    kind,
		Mime:    mime,
		Size:    len(data),
		Preview: preview,
		ThumbW:  thumbWidth,
		ThumbH:  thumbHeight,
		W:       width,
		H:       height,
		Hash:    clipHash(data),
		TS:      time.Now().UnixNano(),
	}
	if thumb != nil && provider.cacheDir != "" {
		path := filepath.Join(provider.cacheDir, fmt.Sprintf("thumb-%016x.png", entry.Hash))
		if err := os.WriteFile(path, thumb, 0o600); err == nil {
			entry.ThumbPath = path
			entry.thumbBytes = len(thumb)
		}
	}
	return entry
}

// storedBytes devuelve bytes totales en disco (payload + thumbnail).
func (entry *Entry) storedBytes() int64 {
	return int64(entry.Size) + int64(entry.thumbBytes)
}

// pushLocked inserta una entrada al frente. Dedup por hash: si ya existe,
// la promueve al frente reusando su id y starred.
func (provider *Provider) pushLocked(entry *Entry) {
	for i, existingEntry := range provider.entries {
		if existingEntry.Hash == entry.Hash {
			entry.ID = existingEntry.ID
			entry.Starred = existingEntry.Starred
			if entry.ThumbPath == "" && existingEntry.ThumbPath != "" {
				entry.ThumbPath = existingEntry.ThumbPath
				entry.ThumbW = existingEntry.ThumbW
				entry.ThumbH = existingEntry.ThumbH
				entry.thumbBytes = existingEntry.thumbBytes
			}
			provider.entries = append(provider.entries[:i], provider.entries[i+1:]...)
			provider.entries = append([]*Entry{entry}, provider.entries...)
			return
		}
	}
	entry.ID = provider.nextID
	provider.nextID++
	provider.entries = append([]*Entry{entry}, provider.entries...)
	if len(provider.entries) > clipMaxEntries {
		provider.dropOldestUnstarredLocked()
	}
}

// dropOldestUnstarredLocked evicta la más antigua sin star.
func (provider *Provider) dropOldestUnstarredLocked() {
	for i := len(provider.entries) - 1; i >= 0; i-- {
		if provider.entries[i].Starred {
			continue
		}
		old := provider.entries[i]
		provider.entries = append(provider.entries[:i], provider.entries[i+1:]...)
		if old.ThumbPath != "" {
			_ = os.Remove(old.ThumbPath)
		}
		if provider.dataDir != "" {
			_ = os.Remove(provider.dataPath(old.Hash))
		}
		return
	}
}

// waylandDisplay resuelve WAYLAND_DISPLAY. El backend puede arrancar antes que
// el compositor (servicio de usuario al inicio), así que si la variable no
// está en el entorno se busca el socket en XDG_RUNTIME_DIR. Sin esto,
// wl-paste/wl-copy fallan con "Failed to connect to a Wayland server" y el
// historial deja de registrar copias nuevas.
func waylandDisplay() string {
	if d := os.Getenv("WAYLAND_DISPLAY"); d != "" {
		return d
	}
	rt := os.Getenv("XDG_RUNTIME_DIR")
	if rt == "" {
		return ""
	}
	entries, err := os.ReadDir(rt)
	if err != nil {
		return ""
	}
	best := ""
	for _, e := range entries {
		name := e.Name()
		if !strings.HasPrefix(name, "wayland-") || strings.HasSuffix(name, ".lock") {
			continue
		}
		info, err := e.Info()
		if err != nil || info.Mode()&os.ModeSocket == 0 {
			continue
		}
		if best == "" || (best != "wayland-0" && name == "wayland-0") {
			best = name
		}
	}
	return best
}

// wlEnv devuelve el entorno para los procesos wl-*, añadiendo WAYLAND_DISPLAY
// descubierto si el servicio no lo heredó.
func wlEnv() []string {
	env := os.Environ()
	if os.Getenv("WAYLAND_DISPLAY") == "" {
		if d := waylandDisplay(); d != "" {
			env = append(env, "WAYLAND_DISPLAY="+d)
		}
	}
	return env
}

// wlCopy envía datos al portapapeles Wayland mediante wl-copy.
func wlCopy(mime string, data io.Reader) error {
	ctx, cancel := context.WithTimeout(context.Background(), clipCmdTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "wl-copy", "--type", mime)
	cmd.Env = wlEnv()
	cmd.Stdin = data
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return fmt.Errorf("wl-copy agotó el tiempo de espera")
		}
		return fmt.Errorf("wl-copy falló: %v (%s)", err, stderr.String())
	}
	return nil
}

// wlPaste lee el contenido actual del portapapeles Wayland mediante wl-paste.
// --no-newline evita añadir un salto que no estaba en el contenido original
// (rompería la deduplicación por hash y el pegado de texto).
func wlPaste(mime string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), clipCmdTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "wl-paste", "--no-newline", "--type", mime)
	cmd.Env = wlEnv()
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return nil, fmt.Errorf("wl-paste agotó el tiempo de espera")
		}
		return nil, fmt.Errorf("wl-paste falló: %v (%s)", err, stderr.String())
	}
	return out.Bytes(), nil
}

// copyClipboard pone datos en el portapapeles del sistema. Usa el protocolo
// Wayland nativo cuando está disponible; si el compositor no ofrece
// wlr-data-control, cae a wl-copy.
func (provider *Provider) copyClipboard(mime string, data []byte) error {
	if c := provider.getWL(); c != nil {
		return c.SetSelection(mime, data)
	}
	return wlCopy(mime, bytes.NewReader(data))
}

// readClipboard devuelve el contenido actual del portapapeles (texto o imagen)
// y su mime. ok=false si no hay nada legible.
func (provider *Provider) readClipboard() (mime string, data []byte, ok bool, err error) {
	if c := provider.getWL(); c != nil {
		return c.ReadCurrent()
	}
	data, err = wlPaste("text/plain;charset=utf-8")
	if err != nil || len(data) == 0 {
		data, err = wlPaste("image/png")
		if err != nil || len(data) == 0 {
			return "", nil, false, nil
		}
		return "image/png", data, true, nil
	}
	return "text/plain;charset=utf-8", data, true, nil
}

func (provider *Provider) setWL(c *wlClient) {
	provider.wlMu.Lock()
	provider.wl = c
	provider.wlMu.Unlock()
}

func (provider *Provider) getWL() *wlClient {
	provider.wlMu.Lock()
	defer provider.wlMu.Unlock()
	return provider.wl
}

// isTextMime reconoce los alias de texto que puede ofrecer un cliente X11/Wayland.
func isTextMime(mime string) bool {
	m := strings.ToLower(mime)
	return strings.HasPrefix(m, "text/") || m == "utf8_string" || m == "string"
}

// CopyText coloca texto libre en el portapapeles Wayland y lo añade al historial.
func (provider *Provider) CopyText(text string) (*Entry, error) {
	if text == "" {
		return nil, fmt.Errorf("texto vacío")
	}

	data := []byte(text)
	mime := "text/plain;charset=utf-8"

	e := provider.buildEntry(mime, data)
	provider.writeData(e.Hash, data)

	if err := provider.copyClipboard(mime, data); err != nil {
		return nil, err
	}

	provider.mu.Lock()
	provider.pushLocked(e)
	provider.persistLocked()
	provider.mu.Unlock()

	provider.markExternalHash(e.Hash)
	provider.notifyChanged()
	return e, nil
}

// CopyImage coloca una imagen (ruta de archivo) en el portapapeles y la añade al historial.
func (provider *Provider) CopyImage(path string) (*Entry, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if info.IsDir() {
		return nil, fmt.Errorf("es un directorio: %s", path)
	}
	if info.Size() == 0 {
		return nil, fmt.Errorf("archivo vacío: %s", path)
	}
	// Comprobar el límite ANTES de leer/copiar: evita cargar en memoria y
	// enviar por el portapapeles archivos enormes que luego se rechazarían.
	if info.Size() > clipMaxEntryBytes {
		return nil, fmt.Errorf("imagen demasiado grande (%d MiB máximo)", clipMaxEntryBytes>>20)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	mime := mimeByExtension(path)

	e := provider.buildEntry(mime, data)
	provider.writeData(e.Hash, data)

	if err := provider.copyClipboard(mime, data); err != nil {
		return nil, err
	}

	provider.mu.Lock()
	provider.pushLocked(e)
	provider.persistLocked()
	provider.mu.Unlock()

	provider.markExternalHash(e.Hash)
	provider.notifyChanged()
	return e, nil
}

// CopyBytes coloca bytes arbitrarios con el mime dado en el portapapeles y el historial.
func (provider *Provider) CopyBytes(mime string, data []byte) (*Entry, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("datos vacíos")
	}
	if len(data) > clipMaxEntryBytes {
		return nil, fmt.Errorf("datos demasiado grandes (%d MiB máximo)", clipMaxEntryBytes>>20)
	}

	e := provider.buildEntry(mime, data)
	provider.writeData(e.Hash, data)

	if err := provider.copyClipboard(mime, data); err != nil {
		return nil, err
	}

	provider.mu.Lock()
	provider.pushLocked(e)
	provider.persistLocked()
	provider.mu.Unlock()

	provider.markExternalHash(e.Hash)
	provider.notifyChanged()
	return e, nil
}

// ingestExternal lee el contenido actual del portapapeles del sistema y, si
// difiere de la última entrada externa vista, lo añade al historial. Es llamado
// por el watch externo.
func (provider *Provider) ingestExternal() error {
	mime, data, ok, err := provider.readClipboard()
	if err != nil {
		return err
	}
	if !ok || len(data) == 0 {
		return nil // nada que hacer
	}

	h := clipHash(data)

	// Eco: si lo que hay en el portapapeles es la selección que posee este
	// mismo cliente, no es una copia externa.
	if c := provider.getWL(); c != nil && c.owns(h) {
		return nil
	}

	provider.watchMu.Lock()
	if h == provider.lastExternalHash {
		provider.watchMu.Unlock()
		return nil // mismo contenido ya visto, eco propio
	}
	provider.lastExternalHash = h
	provider.watchMu.Unlock()

	if isTextMime(mime) {
		mime = "text/plain;charset=utf-8"
	}

	e := provider.buildEntry(mime, data)
	provider.writeData(e.Hash, data)

	provider.mu.Lock()
	provider.pushLocked(e)
	provider.persistLocked()
	provider.mu.Unlock()

	provider.notifyChanged()
	return nil
}

// cloneEntry devuelve una copia de la entrada. El historial comparte
// punteros internamente; exponerlos permitiría que otros goroutines
// modificaran campos (Starred, ThumbPath...) sin el mutex.
func cloneEntry(e *Entry) *Entry {
	if e == nil {
		return nil
	}
	c := *e
	return &c
}

// List devuelve el historial actual (nuevo primero). Los elementos son copias;
// modificarlos no afecta al estado interno.
func (provider *Provider) List() []*Entry {
	provider.mu.Lock()
	defer provider.mu.Unlock()
	out := make([]*Entry, len(provider.entries))
	for i, e := range provider.entries {
		out[i] = cloneEntry(e)
	}
	return out
}

// Paste devuelve el contenido actual del portapapeles como texto.
func (provider *Provider) Paste() (string, error) {
	if c := provider.getWL(); c != nil {
		mime, data, ok, err := c.ReadCurrent()
		if err != nil {
			return "", err
		}
		if !ok {
			return "", fmt.Errorf("el portapapeles está vacío")
		}
		if !isTextMime(mime) {
			return "", fmt.Errorf("el portapapeles no contiene texto")
		}
		return string(data), nil
	}

	data, err := wlPaste("text/plain;charset=utf-8")
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// Delete elimina una entrada del historial y sus archivos asociados.
func (provider *Provider) Delete(id uint64) error {
	provider.mu.Lock()
	for i, e := range provider.entries {
		if e.ID == id {
			if e.ThumbPath != "" {
				_ = os.Remove(e.ThumbPath)
			}
			if provider.dataDir != "" {
				_ = os.Remove(provider.dataPath(e.Hash))
			}
			provider.entries = append(provider.entries[:i], provider.entries[i+1:]...)
			provider.persistLocked()
			provider.mu.Unlock()
			provider.notifyChanged()
			return nil
		}
	}
	provider.mu.Unlock()
	return fmt.Errorf("no existe entrada %d", id)
}

// Clear vacía el historial pero conserva las entradas starred.
func (provider *Provider) Clear() {
	provider.mu.Lock()
	kept := provider.entries[:0]
	for _, e := range provider.entries {
		if e.Starred {
			kept = append(kept, e)
			continue
		}
		if e.ThumbPath != "" {
			_ = os.Remove(e.ThumbPath)
		}
		if provider.dataDir != "" {
			_ = os.Remove(provider.dataPath(e.Hash))
		}
	}
	provider.entries = kept
	provider.persistLocked()
	provider.mu.Unlock()
	provider.notifyChanged()
}

// Star establece el flag starred de una entrada.
func (provider *Provider) Star(id uint64, starred bool) error {
	provider.mu.Lock()
	var found *Entry
	for _, e := range provider.entries {
		if e.ID == id {
			found = e
			break
		}
	}
	if found == nil {
		provider.mu.Unlock()
		return fmt.Errorf("no existe entrada %d", id)
	}
	if starred && !found.Starred {
		var total int64
		for _, e := range provider.entries {
			if e.Starred {
				total += e.storedBytes()
			}
		}
		if total+found.storedBytes() > clipMaxStarredBytes {
			provider.mu.Unlock()
			return fmt.Errorf("límite de starred alcanzado (%d MiB)", clipMaxStarredBytes>>20)
		}
	}
	found.Starred = starred
	provider.persistLocked()
	provider.mu.Unlock()
	provider.notifyChanged()
	return nil
}

// Stats devuelve un resumen del almacenamiento del historial.
func (provider *Provider) Stats() map[string]any {
	provider.mu.Lock()
	defer provider.mu.Unlock()
	st := map[string]any{
		"items":   len(provider.entries),
		"starred": 0,
		"bytes":   int64(0),
	}
	for _, e := range provider.entries {
		st["bytes"] = st["bytes"].(int64) + e.storedBytes()
		if e.Starred {
			st["starred"] = st["starred"].(int) + 1
		}
	}
	return st
}

// writeData persiste los bytes de una entrada una vez, keyados por hash.
func (provider *Provider) writeData(hash uint64, data []byte) {
	if provider.dataDir == "" {
		return
	}
	path := provider.dataPath(hash)
	if _, err := os.Stat(path); err == nil {
		return
	}
	tmp := path + ".tmp"
	if os.WriteFile(tmp, data, 0o600) == nil {
		_ = os.Rename(tmp, path)
	}
}

// persistLocked guarda el índice atómicamente (llamada con mu hold).
func (provider *Provider) persistLocked() {
	if provider.stateDir == "" {
		return
	}
	type persistedEntry struct {
		ID        uint64 `json:"id"`
		Kind      string `json:"kind"`
		Mime      string `json:"mime"`
		Size      int    `json:"size"`
		Preview   string `json:"preview,omitempty"`
		ThumbPath string `json:"thumb,omitempty"`
		ThumbW    int    `json:"thumbW,omitempty"`
		ThumbH    int    `json:"thumbH,omitempty"`
		W         int    `json:"w,omitempty"`
		H         int    `json:"h,omitempty"`
		Starred   bool   `json:"starred"`
		Hash      uint64 `json:"hash"`
		TS        int64  `json:"ts"`
	}
	type persistedIndex struct {
		NextID  uint64           `json:"nextID"`
		Entries []persistedEntry `json:"entries"`
	}
	pe := persistedIndex{NextID: provider.nextID, Entries: make([]persistedEntry, 0, len(provider.entries))}
	for _, e := range provider.entries {
		pe.Entries = append(pe.Entries, persistedEntry{
			ID: e.ID, Kind: e.Kind, Mime: e.Mime, Size: e.Size,
			Preview: e.Preview, ThumbPath: e.ThumbPath, ThumbW: e.ThumbW,
			ThumbH: e.ThumbH, W: e.W, H: e.H, Starred: e.Starred,
			Hash: e.Hash, TS: e.TS,
		})
	}
	b, err := json.Marshal(pe)
	if err != nil {
		return
	}
	tmp := provider.indexPath() + ".tmp"
	if os.WriteFile(tmp, b, 0o600) == nil {
		_ = os.Rename(tmp, provider.indexPath())
	}
}

// load restaura el historial persistido desde index.json. Para cada entrada
// verifica que su payload exista en data/; las entradas huérfanas se descartan.
func (provider *Provider) load() {
	if provider.stateDir == "" {
		return
	}
	raw, err := os.ReadFile(provider.indexPath())
	if err != nil {
		return
	}
	type persistedEntry struct {
		ID        uint64 `json:"id"`
		Kind      string `json:"kind"`
		Mime      string `json:"mime"`
		Size      int    `json:"size"`
		Preview   string `json:"preview,omitempty"`
		ThumbPath string `json:"thumb,omitempty"`
		ThumbW    int    `json:"thumbW,omitempty"`
		ThumbH    int    `json:"thumbH,omitempty"`
		W         int    `json:"w,omitempty"`
		H         int    `json:"h,omitempty"`
		Starred   bool   `json:"starred"`
		Hash      uint64 `json:"hash"`
		TS        int64  `json:"ts"`
	}
	type persistedIndex struct {
		NextID  uint64           `json:"nextID"`
		Entries []persistedEntry `json:"entries"`
	}
	var pi persistedIndex
	if err := json.Unmarshal(raw, &pi); err != nil {
		return
	}
	provider.nextID = pi.NextID
	if provider.nextID == 0 {
		provider.nextID = 1
	}
	for _, pe := range pi.Entries {
		// Solo restaurar si el payload aún existe en disco
		if provider.dataDir != "" {
			if _, err := os.Stat(provider.dataPath(pe.Hash)); err != nil {
				// Payload perdido: descartar entrada
				if pe.ThumbPath != "" {
					_ = os.Remove(pe.ThumbPath)
				}
				continue
			}
		}
		// Verificar que el thumbnail siga existiendo (si lo tenía)
		if pe.ThumbPath != "" {
			if _, err := os.Stat(pe.ThumbPath); err != nil {
				pe.ThumbPath = ""
				pe.ThumbW = 0
				pe.ThumbH = 0
				if pe.Kind == "image" {
					pe.Kind = "binary"
				}
			}
		}
		e := &Entry{
			ID:        pe.ID,
			Kind:      pe.Kind,
			Mime:      pe.Mime,
			Size:      pe.Size,
			Preview:   pe.Preview,
			ThumbPath: pe.ThumbPath,
			ThumbW:    pe.ThumbW,
			ThumbH:    pe.ThumbH,
			W:         pe.W,
			H:         pe.H,
			Starred:   pe.Starred,
			Hash:      pe.Hash,
			TS:        pe.TS,
		}
		// Calcular thumbBytes desde el archivo real
		if pe.ThumbPath != "" {
			if fi, err := os.Stat(pe.ThumbPath); err == nil {
				e.thumbBytes = int(fi.Size())
			}
		}
		provider.entries = append(provider.entries, e)
		if e.ID >= provider.nextID {
			provider.nextID = e.ID + 1
		}
	}
}

// StartWatch abre el acceso nativo al portapapeles Wayland y queda escuchando
// los cambios de selección. Es idempotente: llamarlo de nuevo mientras corre
// no hace nada.
func (provider *Provider) StartWatch() {
	provider.watchStartMu.Lock()
	defer provider.watchStartMu.Unlock()

	provider.watchMu.Lock()
	if provider.watchRunning {
		provider.watchMu.Unlock()
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	provider.watchRunning = true
	provider.watchCancel = cancel
	provider.watchWG.Add(1)
	provider.watchMu.Unlock()

	go func() {
		defer provider.watchWG.Done()
		provider.watchWayland(ctx)
	}()
}

// watchWayland conecta con el compositor y se reconecta si la conexión cae
// (reinicio de Hyprland, suspensión...). Mientras vive, el cliente posee la
// selección y recibe un evento por cada copia, sin polling ni procesos hijos.
func (provider *Provider) watchWayland(ctx context.Context) {
	warned := false
	for ctx.Err() == nil {
		client, err := dialWL()
		if err != nil {
			// Sin wlr-data-control (o sin compositor todavía): modo respaldo
			// con wl-paste periódico, como antes. El aviso se emite una sola
			// vez para no inundar el journal mientras no haya sesión.
			if !warned {
				logger.Warn("clipboard: sin acceso nativo a Wayland; usando wl-clipboard", "error", err)
				warned = true
			}
			// Solo intentar leer si hay un socket Wayland; si no, ahorramos
			// lanzar wl-paste cada dos segundos durante el arranque.
			if waylandDisplay() != "" {
				_ = provider.ingestExternal()
			}
			if !sleepCtx(ctx, 2*time.Second) {
				return
			}
			continue
		}
		warned = false
		provider.setWL(client)
		logger.Info("clipboard: acceso nativo a Wayland",
			"protocolo", "zwlr_data_control_manager_v1")

		err = client.Run(ctx, func() {
			if err := provider.ingestExternal(); err != nil {
				logger.Warn("clipboard: no se pudo leer la selección", "error", err)
			}
		})
		provider.setWL(nil)
		client.Close()

		if ctx.Err() != nil {
			return
		}
		if err != nil {
			logger.Warn("clipboard: conexión Wayland perdida", "error", err)
		}
		if !sleepCtx(ctx, 2*time.Second) {
			return
		}
	}
}

// sleepCtx duerme d o hasta que se cancele el contexto. Devuelve false si se
// canceló.
func sleepCtx(ctx context.Context, d time.Duration) bool {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-t.C:
		return true
	}
}

// StopWatch detiene el watcher nativo y espera a que termine su goroutine.
func (provider *Provider) StopWatch() {
	provider.watchStartMu.Lock()
	defer provider.watchStartMu.Unlock()

	provider.watchMu.Lock()
	if !provider.watchRunning {
		provider.watchMu.Unlock()
		return
	}
	provider.watchRunning = false
	cancel := provider.watchCancel
	provider.watchCancel = nil
	provider.watchMu.Unlock()

	if cancel != nil {
		cancel()
	}
	// watchStartMu impide que StartWatch haga Add mientras esperamos, y no
	// se retiene watchMu (los watchers lo usan al ingerir datos).
	provider.watchWG.Wait()
}

// GetEntry devuelve una copia de la entrada por su id (o nil si no existe).
func (provider *Provider) GetEntry(id uint64) *Entry {
	provider.mu.Lock()
	defer provider.mu.Unlock()
	for _, e := range provider.entries {
		if e.ID == id {
			return cloneEntry(e)
		}
	}
	return nil
}

// GetContent devuelve los bytes persistidos de una entrada por su hash.
func (provider *Provider) GetContent(hash uint64) ([]byte, error) {
	if provider.dataDir == "" {
		return nil, fmt.Errorf("persistencia desactivada")
	}
	return os.ReadFile(provider.dataPath(hash))
}

// PromoteEntry mueve una entrada al frente del historial (tras un recopy).
func (provider *Provider) PromoteEntry(id uint64) {
	provider.mu.Lock()
	for i, e := range provider.entries {
		if e.ID == id {
			provider.entries = append(provider.entries[:i], provider.entries[i+1:]...)
			provider.entries = append([]*Entry{e}, provider.entries...)
			provider.persistLocked()
			provider.mu.Unlock()
			provider.notifyChanged()
			return
		}
	}
	provider.mu.Unlock()
}

// Recopy lee el contenido de una entrada y lo vuelve a poner en el
// portapapeles Wayland, promoviéndola al frente del historial.
func (provider *Provider) Recopy(id uint64) error {
	provider.mu.Lock()
	var (
		hash  uint64
		mime  string
		found bool
	)
	for _, e := range provider.entries {
		if e.ID == id {
			hash = e.Hash
			mime = e.Mime
			found = true
			break
		}
	}
	provider.mu.Unlock()

	if !found {
		return fmt.Errorf("no existe entrada %d", id)
	}

	data, err := provider.GetContent(hash)
	if err != nil {
		return err
	}
	if err := provider.copyClipboard(mime, data); err != nil {
		return err
	}

	provider.markExternalHash(hash)
	provider.PromoteEntry(id)
	return nil
}

// mimeByExtension devuelve el mime basado en la extensión del archivo.
func mimeByExtension(path string) string {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".png":
		return "image/png"
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".gif":
		return "image/gif"
	default:
		return "application/octet-stream"
	}
}

// detectMime intenta adivinar el MIME leyendo los bytes mágicos (magic numbers).
func detectMime(data []byte) string {
	if len(data) < 4 {
		return "text/plain;charset=utf-8"
	}
	switch {
	case data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4e && data[3] == 0x47:
		return "image/png"
	case data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF:
		return "image/jpeg"
	case data[0] == 'G' && data[1] == 'I' && data[2] == 'F':
		return "image/gif"
	case len(data) >= 12 && data[0] == 'R' && data[1] == 'I' && data[2] == 'F' && data[3] == 'F' && data[8] == 'W' && data[9] == 'E' && data[10] == 'B' && data[11] == 'P':
		return "image/webp"
	default:
		// Heurística: si empieza con bytes imprimibles o UTF-8 válido, asumimos texto
		if utf8.Valid(data) {
			return "text/plain;charset=utf-8"
		}
		return "application/octet-stream"
	}
}

// importEntry agrega una entrada al historial sin copiar al portapapeles del sistema
// (usa para importar historial externo como cliphist). Es como CopyBytes pero sin
// llamar a wlCopy.
func (provider *Provider) importEntry(mime string, data []byte) (*Entry, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("datos vacíos")
	}
	if len(data) > clipMaxEntryBytes {
		return nil, fmt.Errorf("datos demasiado grandes (%d MiB máximo)", clipMaxEntryBytes>>20)
	}

	e := provider.buildEntry(mime, data)
	provider.writeData(e.Hash, data)

	provider.mu.Lock()
	provider.pushLocked(e)
	provider.persistLocked()
	provider.mu.Unlock()

	provider.notifyChanged()
	return e, nil
}

// ImportCliphist importa el historial de cliphist al backend. Lee cada entrada
// con `cliphist list`, decodifica su contenido con `cliphist decode <id>` y la
// agrega al historial persistente del backend sin tocar el portapapeles del
// sistema. Las entradas ya existentes (por hash) se deducen automáticamente.
func (provider *Provider) ImportCliphist() error {
	cmd := exec.Command("cliphist", "list")
	out, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("cliphist list falló: %v", err)
	}

	lines := strings.Split(string(out), "\n")
	imported := 0
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Formato: <id>\t<preview>
		parts := strings.SplitN(line, "\t", 2)
		if len(parts) < 2 {
			continue
		}
		idStr := parts[0]

		// Decodificar el contenido completo de la entrada.
		decodeCmd := exec.Command("cliphist", "decode", idStr)
		data, err := decodeCmd.Output()
		if err != nil {
			// Si falla el decode, saltar esta entrada
			continue
		}

		mime := detectMime(data)

		// Intentar importar; si ya existe (por hash), pushLocked la deducirá.
		if _, err := provider.importEntry(mime, data); err != nil {
			// Ignorar errores individuales, continuar con la siguiente
			continue
		}
		imported++
	}

	logger.Info("cliphist importado", "entradas", imported)
	return nil
}
