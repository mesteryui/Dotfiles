package clipboard

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

// B1: una colisión de hash (FNV-64a, no criptográfico) no debe corromper ni
// confundir contenido. Si dos payloads distintos colisionan, el proveedor debe
// desambiguar el almacenamiento y devolver el contenido correcto.
func TestHashCollisionMustNotCorruptPayload(t *testing.T) {
	dir := t.TempDir()
	p := New(dir)

	a := []byte("contenido-A")
	b := []byte("contenido-B-distinto")

	ea := p.buildEntry("text/plain;charset=utf-8", a)
	eb := p.buildEntry("text/plain;charset=utf-8", b)
	// Simula colisión: dos contenidos distintos con el mismo hash FNV.
	eb.Hash = ea.Hash

	ha, err := p.writeData(ea.Hash, a)
	if err != nil {
		t.Fatalf("writeData(a): %v", err)
	}
	hb, err := p.writeData(eb.Hash, b)
	if err != nil {
		t.Fatalf("writeData(b): %v", err)
	}
	if ha == hb {
		t.Fatal("colisión de hash: contenidos distintos no pueden compartir la misma clave de almacenamiento")
	}

	gotA, err := os.ReadFile(p.dataPath(ha))
	if err != nil {
		t.Fatalf("leer payload A: %v", err)
	}
	if !bytes.Equal(gotA, a) {
		t.Fatalf("payload A corrupto: got %q", gotA)
	}
	gotB, err := os.ReadFile(p.dataPath(hb))
	if err != nil {
		t.Fatalf("leer payload B: %v", err)
	}
	if !bytes.Equal(gotB, b) {
		t.Fatalf("payload B corrupto: got %q", gotB)
	}

	ea.Hash = ha
	eb.Hash = hb
	p.mu.Lock()
	p.pushLocked(ea)
	p.pushLocked(eb)
	p.persistLocked()
	p.mu.Unlock()

	list := p.List()
	if len(list) != 2 {
		t.Fatalf("se esperaban 2 entradas, got %d", len(list))
	}
	// eb fue pusheada al frente
	content, err := p.GetContent(list[0].Hash)
	if err != nil {
		t.Fatalf("GetContent: %v", err)
	}
	if !bytes.Equal(content, b) {
		t.Fatalf("GetContent devolvió payload equivocado tras colisión: got %q", content)
	}
}

// B2: un fallo al persistir el payload no debe ser silencioso.
func TestPayloadWriteFailureMustNotCauseSilentDataLoss(t *testing.T) {
	dir := t.TempDir()
	p := New(dir)

	dataDir := filepath.Join(dir, "data")
	if err := os.Chmod(dataDir, 0o000); err != nil {
		t.Fatalf("chmod data: %v", err)
	}
	t.Cleanup(func() { _ = os.Chmod(dataDir, 0o700) })

	_, err := p.writeData(clipHash([]byte("hola")), []byte("hola"))
	if err == nil {
		t.Fatal("writeData debería devolver error cuando no puede persistir el payload")
	}
}
