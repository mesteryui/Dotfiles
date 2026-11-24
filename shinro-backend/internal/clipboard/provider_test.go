package clipboard

import (
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
)

// testPNG genera un PNG válido y pequeño para las entradas de imagen.
func testPNG(t *testing.T) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 8, 8))
	for y := range 8 {
		for x := range 8 {
			img.Set(x, y, color.RGBA{R: uint8(x * 30), G: uint8(y * 30), B: 128, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("png.Encode: %v", err)
	}
	return buf.Bytes()
}

type testIndexEntry struct {
	ID      uint64 `json:"id"`
	Kind    string `json:"kind"`
	Mime    string `json:"mime"`
	Size    int    `json:"size"`
	Preview string `json:"preview,omitempty"`
	Thumb   string `json:"thumb,omitempty"`
	ThumbW  int    `json:"thumbW,omitempty"`
	ThumbH  int    `json:"thumbH,omitempty"`
	W       int    `json:"w,omitempty"`
	H       int    `json:"h,omitempty"`
	Starred bool   `json:"starred"`
	Hash    uint64 `json:"hash"`
	TS      int64  `json:"ts"`
}

func writeTestIndex(t *testing.T, dir string, nextID uint64, entries []testIndexEntry) {
	t.Helper()
	raw, err := json.Marshal(map[string]any{"nextID": nextID, "entries": entries})
	if err != nil {
		t.Fatalf("json.Marshal: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "index.json"), raw, 0o600); err != nil {
		t.Fatalf("write index: %v", err)
	}
}

func writeTestPayload(t *testing.T, dir string, hash uint64, data []byte) string {
	t.Helper()
	path := filepath.Join(dir, "data", fmt.Sprintf("%016x.bin", hash))
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatalf("MkdirAll: %v", err)
	}
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatalf("write payload: %v", err)
	}
	return path
}

// List no debe publicar una miniatura que ya no existe: limpia la ruta,
// degrada la entrada y persiste el índice saneado.
func TestListClearsMissingThumb(t *testing.T) {
	dir := t.TempDir()
	provider := New(dir)

	data := testPNG(t)
	hash := clipHash(data)
	writeTestPayload(t, dir, hash, data)
	thumb, tw, th, _, _, ok := thumbnailPNG(data, clipThumbnailSize)
	if !ok {
		t.Fatal("thumbnailPNG falló con un PNG válido")
	}
	thumbPath := filepath.Join(provider.cacheDir, fmt.Sprintf("thumb-%016x.png", hash))
	if err := os.WriteFile(thumbPath, thumb, 0o600); err != nil {
		t.Fatalf("write thumb: %v", err)
	}
	provider.entries = []*Entry{{
		ID: 1, Kind: "image", Mime: "image/png", Size: len(data), Hash: hash,
		ThumbPath: thumbPath, ThumbW: tw, ThumbH: th, thumbBytes: len(thumb),
	}}

	// Borrado externo del cache con el daemon vivo.
	if err := os.Remove(thumbPath); err != nil {
		t.Fatalf("remove thumb: %v", err)
	}

	list := provider.List()
	if len(list) != 1 {
		t.Fatalf("List() devolvió %d entradas, quiero 1", len(list))
	}
	if list[0].ThumbPath != "" {
		t.Fatalf("ThumbPath = %q, quiero vacío (miniatura inexistente)", list[0].ThumbPath)
	}
	if list[0].Kind != "binary" {
		t.Fatalf("Kind = %q, quiero binary (sin preview)", list[0].Kind)
	}

	raw, err := os.ReadFile(provider.indexPath())
	if err != nil {
		t.Fatalf("read index: %v", err)
	}
	if bytes.Contains(raw, []byte("thumb-")) {
		t.Fatalf("el índice persistido conserva una miniatura muerta: %s", raw)
	}
}

// Una entrada sin payload ya no se puede recopiar: List la descarta y borra
// su miniatura.
func TestListDropsMissingPayload(t *testing.T) {
	dir := t.TempDir()
	provider := New(dir)

	thumbPath := filepath.Join(provider.cacheDir, "thumb-deadbeefdeadbeef.png")
	if err := os.WriteFile(thumbPath, []byte("png"), 0o600); err != nil {
		t.Fatalf("write thumb: %v", err)
	}
	provider.entries = []*Entry{{
		ID: 1, Kind: "image", Mime: "image/png", Hash: 42,
		ThumbPath: thumbPath, thumbBytes: 3,
	}}

	list := provider.List()
	if len(list) != 0 {
		t.Fatalf("List() devolvió %d entradas, quiero 0 (payload perdido)", len(list))
	}
	if _, err := os.Stat(thumbPath); !os.IsNotExist(err) {
		t.Fatalf("la miniatura huérfana sigue en disco: %v", err)
	}
}

// Al arrancar, una miniatura perdida se regenera desde el payload en vez de
// degradar la entrada a binaria.
func TestLoadRegeneratesMissingThumb(t *testing.T) {
	dir := t.TempDir()
	data := testPNG(t)
	hash := clipHash(data)
	writeTestPayload(t, dir, hash, data)
	writeTestIndex(t, dir, 2, []testIndexEntry{{
		ID: 1, Kind: "image", Mime: "image/png", Size: len(data), Hash: hash,
		Thumb: filepath.Join(dir, "cache", "thumb-missing.png"), ThumbW: 8, ThumbH: 8, W: 8, H: 8,
	}})

	provider := New(dir)
	if len(provider.entries) != 1 {
		t.Fatalf("load() restauró %d entradas, quiero 1", len(provider.entries))
	}
	e := provider.entries[0]
	if e.Kind != "image" {
		t.Fatalf("Kind = %q, quiero image (miniatura regenerable)", e.Kind)
	}
	if e.ThumbPath == "" {
		t.Fatal("ThumbPath vacío: no se regeneró la miniatura")
	}
	if _, err := os.Stat(e.ThumbPath); err != nil {
		t.Fatalf("miniatura regenerada inexistente: %v", err)
	}
}

// El arranque elimina thumbnails y payloads que el índice no referencia
// (restos de un cierre abrupto o de un índice perdido).
func TestNewRemovesOrphanFiles(t *testing.T) {
	dir := t.TempDir()
	data := []byte("hola")
	hash := clipHash(data)
	writeTestPayload(t, dir, hash, data)
	writeTestIndex(t, dir, 2, []testIndexEntry{{
		ID: 1, Kind: "text", Mime: "text/plain;charset=utf-8", Size: len(data), Preview: "hola", Hash: hash,
	}})

	orphanThumb := filepath.Join(dir, "cache", "thumb-deadbeefdeadbeef.png")
	orphanData := filepath.Join(dir, "data", "deadbeefdeadbeef.bin")
	orphanTmp := filepath.Join(dir, "data", "cafe.bin.tmp")
	for _, path := range []string{orphanThumb, orphanData, orphanTmp} {
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			t.Fatalf("MkdirAll: %v", err)
		}
		if err := os.WriteFile(path, []byte("x"), 0o600); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
	}

	provider := New(dir)
	if len(provider.entries) != 1 {
		t.Fatalf("load() restauró %d entradas, quiero 1", len(provider.entries))
	}
	for _, path := range []string{orphanThumb, orphanData, orphanTmp} {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Errorf("huérfano no eliminado: %s (%v)", path, err)
		}
	}
	if _, err := os.Stat(filepath.Join(dir, "data", fmt.Sprintf("%016x.bin", hash))); err != nil {
		t.Errorf("payload referenciado eliminado por error: %v", err)
	}
}

// Un índice antiguo con más de clipMaxEntries se recorta al cargar, sin
// descartar la entrada más nueva.
func TestLoadTrimsHistoryKeepingNewest(t *testing.T) {
	dir := t.TempDir()
	total := clipMaxEntries + 5
	entries := make([]testIndexEntry, 0, total)
	for i := range total {
		data := []byte(fmt.Sprintf("item-%d", i))
		hash := clipHash(data)
		writeTestPayload(t, dir, hash, data)
		entries = append(entries, testIndexEntry{
			ID: uint64(i + 1), Kind: "text", Mime: "text/plain;charset=utf-8",
			Size: len(data), Preview: string(data), Hash: hash,
		})
	}
	writeTestIndex(t, dir, uint64(total+1), entries)

	provider := New(dir)
	if len(provider.entries) != clipMaxEntries {
		t.Fatalf("load() dejó %d entradas, quiero %d", len(provider.entries), clipMaxEntries)
	}
	if provider.entries[0].ID != 1 {
		t.Fatalf("la entrada más nueva se perdió: ID %d, quiero 1", provider.entries[0].ID)
	}
	if provider.entries[len(provider.entries)-1].ID != uint64(clipMaxEntries) {
		t.Fatalf("última entrada ID %d, quiero %d", provider.entries[len(provider.entries)-1].ID, clipMaxEntries)
	}
}

// Con todas las entradas starred, una copia nueva debe seguir entrando (la
// más nueva nunca se evicta); la anterior sin star se descarta.
func TestPushWithAllStarredKeepsNewest(t *testing.T) {
	provider := New("")
	for i := range clipMaxEntries {
		provider.entries = append(provider.entries, &Entry{
			ID: uint64(i + 1), Kind: "text", Starred: true, Hash: uint64(i + 1),
		})
	}

	first := &Entry{ID: 1000, Kind: "text", Hash: 1000}
	provider.pushLocked(first)
	if len(provider.entries) != clipMaxEntries+1 {
		t.Fatalf("tras la primera copia hay %d entradas, quiero %d", len(provider.entries), clipMaxEntries+1)
	}
	if provider.entries[0] != first {
		t.Fatal("la copia nueva no está al frente")
	}

	second := &Entry{ID: 1001, Kind: "text", Hash: 1001}
	provider.pushLocked(second)
	if len(provider.entries) != clipMaxEntries+1 {
		t.Fatalf("tras la segunda copia hay %d entradas, quiero %d", len(provider.entries), clipMaxEntries+1)
	}
	if provider.entries[0] != second {
		t.Fatal("la segunda copia no está al frente")
	}
	for _, e := range provider.entries {
		if e == first {
			t.Fatal("la copia anterior debía evictarse al no estar starred")
		}
	}
}

func TestCopyTextRejectsTooLarge(t *testing.T) {
	provider := New(t.TempDir())
	largeText := string(make([]byte, clipMaxEntryBytes+1))
	if _, err := provider.CopyText(largeText); err == nil {
		t.Fatal("esperaba error al copiar texto superior al límite máximo")
	}
}

func TestCopyImageRejectsNonImage(t *testing.T) {
	provider := New(t.TempDir())
	tmpFile := filepath.Join(t.TempDir(), "id_rsa")
	if err := os.WriteFile(tmpFile, []byte("clave-privada"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := provider.CopyImage(tmpFile); err == nil {
		t.Fatal("esperaba error al intentar copiar un archivo que no es imagen")
	}
}
