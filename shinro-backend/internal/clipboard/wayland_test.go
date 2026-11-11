package clipboard

import (
	"bytes"
	"testing"
)

func TestEncoderStringPadding(t *testing.T) {
	e := &wlEncoder{}
	e.str("hola")
	want := []byte{
		5, 0, 0, 0,
		'h', 'o', 'l', 'a', 0, 0, 0, 0,
	}
	if !bytes.Equal(e.buf, want) {
		t.Fatalf("str = %v, quiero %v", e.buf, want)
	}
}

func TestDecoderRoundtrip(t *testing.T) {
	e := &wlEncoder{}
	e.u32(42)
	e.str("abc")
	e.u32(7)

	d := &wlDecoder{buf: e.buf}
	if got := d.u32(); got != 42 {
		t.Fatalf("u32 = %d, quiero 42", got)
	}
	if got := d.str(); got != "abc" {
		t.Fatalf("str = %q, quiero %q", got, "abc")
	}
	if got := d.u32(); got != 7 {
		t.Fatalf("u32 = %d, quiero 7", got)
	}
	if d.off != len(e.buf) {
		t.Fatalf("off = %d, quiero %d", d.off, len(e.buf))
	}
}

func TestDecoderTruncatedNoPanic(t *testing.T) {
	d := &wlDecoder{buf: []byte{1, 2}}
	if got := d.u32(); got != 0 {
		t.Fatalf("u32 truncado = %d, quiero 0", got)
	}
	d = &wlDecoder{buf: []byte{9, 0, 0, 0, 'x'}}
	if got := d.str(); got != "" {
		t.Fatalf("str truncado = %q, quiero vacío", got)
	}
}

func TestChooseMime(t *testing.T) {
	tests := []struct {
		name  string
		mimes []string
		want  string
	}{
		{"texto utf8", []string{"text/html", "text/plain;charset=utf-8"}, "text/plain;charset=utf-8"},
		{"texto simple", []string{"UTF8_STRING", "image/png"}, "UTF8_STRING"},
		{"imagen", []string{"image/jpeg", "image/png"}, "image/png"},
		{"sin tipos útiles", []string{"application/x-foo"}, ""},
		{"vacío", nil, ""},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := chooseMime(tc.mimes); got != tc.want {
				t.Fatalf("chooseMime(%v) = %q, quiero %q", tc.mimes, got, tc.want)
			}
		})
	}
}

func TestMimesFor(t *testing.T) {
	got := mimesFor("text/plain;charset=utf-8")
	if len(got) == 0 || got[0] != "text/plain;charset=utf-8" {
		t.Fatalf("mimesFor texto = %v", got)
	}
	seen := make(map[string]bool)
	for _, m := range got {
		key := m
		if seen[key] {
			t.Fatalf("mime duplicado: %q", m)
		}
		seen[key] = true
	}
	for _, want := range []string{"text/plain", "UTF8_STRING", "STRING", "TEXT"} {
		if !seen[want] {
			t.Fatalf("falta %q en %v", want, got)
		}
	}

	img := mimesFor("image/png")
	if len(img) != 1 || img[0] != "image/png" {
		t.Fatalf("mimesFor imagen = %v", img)
	}

	html := mimesFor("text/html")
	if len(html) != 1 || html[0] != "text/html" {
		t.Fatalf("mimesFor text/html = %v", html)
	}
}

func TestIsTextMime(t *testing.T) {
	for _, m := range []string{"text/plain;charset=utf-8", "TEXT/HTML", "UTF8_STRING", "STRING"} {
		if !isTextMime(m) {
			t.Fatalf("%q debería ser texto", m)
		}
	}
	for _, m := range []string{"image/png", "application/octet-stream", ""} {
		if isTextMime(m) {
			t.Fatalf("%q no debería ser texto", m)
		}
	}
}
