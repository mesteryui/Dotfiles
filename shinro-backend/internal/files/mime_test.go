package files

import (
	"os"
	"path/filepath"
	"testing"
)

func TestKindForMime(t *testing.T) {
	tests := []struct {
		typ  string
		want string
	}{
		{"image/png", KindImage},
		{"image/svg+xml", KindImage},
		{"text/plain; charset=utf-8", KindText},
		{"text/x-qml; charset=utf-8", KindText},
		{"audio/mpeg", KindAudio},
		{"video/mp4", KindVideo},
		{"application/pdf", KindPDF},
		{"application/json", KindText},
		{"application/yaml", KindText},
		{"application/toml", KindText},
		{"application/x-desktop", KindText},
		{"application/vnd.api+json", KindText},
		{"application/zip", KindArchive},
		{"application/octet-stream", KindBinary},
		{"", KindOther},
	}
	for _, tc := range tests {
		if got := kindForMime(tc.typ); got != tc.want {
			t.Errorf("kindForMime(%q) = %q, quiero %q", tc.typ, got, tc.want)
		}
	}
}

func writeFile(t *testing.T, dir, name string, data []byte) string {
	t.Helper()
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatalf("escribir %s: %v", path, err)
	}
	return path
}

func TestDetectMime(t *testing.T) {
	dir := t.TempDir()

	pngHeader := []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n', 0, 0, 0, 0}
	pdfHeader := []byte("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
	binaryData := []byte{0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07}

	tests := []struct {
		name     string
		file     string
		data     []byte
		wantMime string
		wantKind string
	}{
		{"extensión de imagen manda", "foto.png", []byte("no soy png"), "image/png", KindImage},
		{"pdf por extensión", "doc.pdf", pdfHeader, "application/pdf", KindPDF},
		{"json por extensión", "datos.json", []byte(`{"a":1}`), "application/json", KindText},
		{"zip sin preview", "paquete.zip", []byte("PK\x03\x04"), "application/zip", KindArchive},
		{"sin extensión, texto", "notas", []byte("hola mundo\nsegunda línea\n"), "text/plain; charset=utf-8", KindText},
		{"extensión desconocida, texto", "app.conf", []byte("clave=valor\n"), "text/plain; charset=utf-8", KindText},
		{"extensión desconocida, imagen", "volcado.dat", pngHeader, "image/png", KindImage},
		{"sin extensión, binario", "blob", binaryData, "application/octet-stream", KindBinary},
		{"vacío sin extensión", "vacio", nil, "inode/x-empty", KindOther},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			path := writeFile(t, dir, tc.file, tc.data)
			gotMime, gotKind := detectMime(path, int64(len(tc.data)))
			if gotMime != tc.wantMime || gotKind != tc.wantKind {
				t.Fatalf("detectMime(%s) = (%q, %q), quiero (%q, %q)",
					tc.file, gotMime, gotKind, tc.wantMime, tc.wantKind)
			}
		})
	}
}

func TestNewResult(t *testing.T) {
	dir := t.TempDir()
	path := writeFile(t, dir, "script.sh", []byte("#!/bin/sh\necho hola\n"))

	r := newResult(path, "script.sh", 20)
	if r.Path != path || r.Name != "script.sh" || r.Size != 20 {
		t.Fatalf("campos base incorrectos: %+v", r)
	}
	if r.Kind != KindText || r.Mime == "" {
		t.Fatalf("kind/mime = %q/%q, quiero text y mime no vacío", r.Kind, r.Mime)
	}
}
