package clipboard

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Adversarial audit: wlPaste buffers the full stdout before checking size,
// so an oversized clipboard payload is fully read into memory.
func TestWlPasteRejectsOversizedWithoutReadingAll(t *testing.T) {
	dir := t.TempDir()
	script := filepath.Join(dir, "wl-paste")
	// Write limit+1 bytes, then sleep to keep the process alive. If wlPaste
	// buffers everything before enforcing the limit, it will wait for process exit.
	payloadSize := clipMaxEntryBytes + 1
	content := fmt.Sprintf("#!/bin/sh\nhead -c %d /dev/zero\nsleep 5\n", payloadSize)
	if err := os.WriteFile(script, []byte(content), 0o755); err != nil {
		t.Fatalf("write fake wl-paste: %v", err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))

	start := time.Now()
	_, err := wlPaste("text/plain")
	elapsed := time.Since(start)

	if err == nil {
		t.Fatal("expected error for oversized clipboard content, got nil")
	}
	if elapsed > 2*time.Second {
		t.Fatalf("wlPaste took %v; it should reject oversized input before reading/draining the full process output", elapsed)
	}
}
