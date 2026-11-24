package files

import (
	"os"
	"path/filepath"
	"testing"
)

// Adversarial audit: addSubtree rebases depth on the newly created directory,
// so it can watch directories deeper than maxDepth from the search root.
func TestWatcherAddSubtreeRespectsMaxDepthFromRoot(t *testing.T) {
	root := t.TempDir()
	// Build a path at depth maxDepth from root.
	deep := root
	for i := 0; i < maxDepth; i++ {
		deep = filepath.Join(deep, string(rune('a'+i)))
		if err := os.Mkdir(deep, 0o755); err != nil {
			t.Fatalf("mkdir %s: %v", deep, err)
		}
	}

	w, err := newWatcher(func() {})
	if err != nil {
		t.Skipf("inotify unavailable: %v", err)
	}
	t.Cleanup(func() { w.close() })
	w.watchTree(root)

	// Create children beyond maxDepth.
	extra1 := filepath.Join(deep, "extra1") // depth maxDepth+1 from root
	extra2 := filepath.Join(extra1, "extra2")
	if err := os.MkdirAll(extra2, 0o755); err != nil {
		t.Fatalf("mkdir extra: %v", err)
	}

	w.addSubtree(deep, "extra1")

	w.mu.Lock()
	_, watched1 := w.paths[extra1]
	_, watched2 := w.paths[extra2]
	w.mu.Unlock()

	if watched1 || watched2 {
		t.Fatalf("directories beyond maxDepth should not be watched; extra1=%v extra2=%v", watched1, watched2)
	}
}
