package updates

import (
	"os"
	"os/exec"
	"testing"
)

func fixture(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatalf("leyendo fixture %s: %v", name, err)
	}
	return data
}

func names(pkgs []Package) []string {
	out := make([]string, len(pkgs))
	for i, p := range pkgs {
		out[i] = p.Name
	}
	return out
}

func TestParseCheckupdates(t *testing.T) {
	b := newPacman(nil, "checkupdates")
	pkgs, err := b.Parse(fixture(t, "checkupdates.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 5 {
		t.Fatalf("paquetes = %d, quiero 5", len(pkgs))
	}
	if pkgs[0].Name != "blocky" || pkgs[0].Old != "0.36.0-1" || pkgs[0].New != "0.37.0-1" {
		t.Fatalf("primer paquete inesperado: %+v", pkgs[0])
	}
	if pkgs[4].Name != "croc" || pkgs[4].Old != "1:11.6.5-1.1" || pkgs[4].New != "1:11.6.6-1.1" {
		t.Fatalf("época mal parseada: %+v", pkgs[4])
	}
	if pkgs[0].Backend != "pacman" {
		t.Fatalf("backend = %q", pkgs[0].Backend)
	}

	// checkupdates usa exit 2 para "no hay actualizaciones".
	empty, err := b.Parse(nil, 2)
	if err != nil {
		t.Fatalf("exit 2 no debe ser error: %v", err)
	}
	if len(empty) != 0 {
		t.Fatalf("exit 2 devolvió %d paquetes", len(empty))
	}

	if _, err := b.Parse(nil, 1); err == nil {
		t.Fatal("exit 1 debe ser error")
	}
}

func TestParsePacmanFallback(t *testing.T) {
	b := newPacman(nil, "pacman")
	pkgs, err := b.Parse(fixture(t, "checkupdates.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 5 {
		t.Fatalf("paquetes = %d", len(pkgs))
	}
	if _, err := b.Parse(nil, 1); err != nil {
		t.Fatalf("pacman -Qu usa exit 1 para 'sin actualizaciones': %v", err)
	}
}

func TestParseParu(t *testing.T) {
	b := newAUR(nil, "paru")
	pkgs, err := b.Parse(fixture(t, "paru.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 1 || pkgs[0].Name != "portop-bin" || pkgs[0].Backend != "aur" {
		t.Fatalf("paquetes inesperados: %+v", pkgs)
	}
}

func TestParseYayStripsTimeSuffix(t *testing.T) {
	b := newAUR(nil, "yay")
	pkgs, err := b.Parse(fixture(t, "yay.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 1 {
		t.Fatalf("paquetes = %d", len(pkgs))
	}
	if pkgs[0].New != "0.4.1-1" {
		t.Fatalf("versión nueva = %q (no se quitó [1h15m])", pkgs[0].New)
	}
}

func TestParseFlatpak(t *testing.T) {
	b := newFlatpak(nil)
	pkgs, err := b.Parse(fixture(t, "flatpak.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 3 {
		t.Fatalf("paquetes = %d, quiero 3", len(pkgs))
	}
	if pkgs[0].Name != "com.github.tchx84.Flatseal" || pkgs[0].New != "2.4.2" {
		t.Fatalf("primer paquete inesperado: %+v", pkgs[0])
	}
	if pkgs[0].Backend != "flatpak" {
		t.Fatalf("backend = %q", pkgs[0].Backend)
	}
}

func TestParseFlatpakMulti(t *testing.T) {
	b := newFlatpak(nil)
	outputs := []Output{
		{Stdout: fixture(t, "flatpak.txt"), Exit: 0},
		{Stdout: []byte("com.github.tchx84.Flatseal\t2.4.2\tstable\tflathub\n"), Exit: 0},
	}
	pkgs, err := b.(multiBackend).ParseMulti(outputs)
	if err != nil {
		t.Fatalf("ParseMulti: %v", err)
	}
	// El duplicado se colapsa.
	if len(pkgs) != 3 {
		t.Fatalf("paquetes = %d, quiero 3 (sin duplicados)", len(pkgs))
	}
}

func TestParseDNF(t *testing.T) {
	b := newDNF(nil)
	pkgs, err := b.Parse(fixture(t, "dnf-check-update.txt"), 100)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 2 {
		t.Fatalf("paquetes = %d, quiero 2", len(pkgs))
	}
	if pkgs[0].Name != "kernel" || pkgs[0].New != "6.8.5-301.fc40" {
		t.Fatalf("paquete inesperado: %+v", pkgs[0])
	}
	if pkgs[0].Backend != "dnf" {
		t.Fatalf("backend = %q", pkgs[0].Backend)
	}
	if _, err := b.Parse(nil, 1); err == nil {
		t.Fatal("exit 1 de dnf debe ser error")
	}
}

func TestParseAPT(t *testing.T) {
	b := newAPT(nil)
	pkgs, err := b.Parse(fixture(t, "apt-list-upgradable.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 2 {
		t.Fatalf("paquetes = %d, quiero 2", len(pkgs))
	}
	if pkgs[0].Name != "bash" || pkgs[0].Old != "5.2.15-2+b6" || pkgs[0].New != "5.2.15-2+b7" {
		t.Fatalf("paquete inesperado: %+v", pkgs[0])
	}
}

func TestParseXBPS(t *testing.T) {
	b := newXBPS(nil)
	pkgs, err := b.Parse(fixture(t, "xbps-install-un.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 2 {
		t.Fatalf("paquetes = %d, quiero 2", len(pkgs))
	}
	if pkgs[0].Name != "libxbps" || pkgs[0].Old != "0.59.2_4" || pkgs[0].New != "0.60.2_1" {
		t.Fatalf("paquete inesperado: %+v", pkgs[0])
	}
}

func TestCommandBackendLines(t *testing.T) {
	b, err := NewCommandBackend(CommandSpec{Argv: []string{"mi-gestor"}, Format: "lines"})
	if err != nil {
		t.Fatalf("NewCommandBackend: %v", err)
	}
	pkgs, err := b.Parse(fixture(t, "command-lines.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if got := names(pkgs); len(got) != 2 || got[0] != "foo" || got[1] != "bar" {
		t.Fatalf("nombres = %v", got)
	}
}

func TestCommandBackendLinesVersions(t *testing.T) {
	b, err := NewCommandBackend(CommandSpec{Argv: []string{"mi-gestor"}, Format: "lines-versions"})
	if err != nil {
		t.Fatalf("NewCommandBackend: %v", err)
	}
	pkgs, err := b.Parse(fixture(t, "command-lines-versions.txt"), 0)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if len(pkgs) != 2 {
		t.Fatalf("paquetes = %d", len(pkgs))
	}
	if pkgs[0].Name != "foo" || pkgs[0].Old != "1.0" || pkgs[0].New != "1.1" {
		t.Fatalf("paquete con flecha inesperado: %+v", pkgs[0])
	}
	if pkgs[1].Name != "bar" || pkgs[1].Old != "2.0" || pkgs[1].New != "2.1" {
		t.Fatalf("paquete sin flecha inesperado: %+v", pkgs[1])
	}
}

func TestCommandBackendRejectsInvalidSpec(t *testing.T) {
	if _, err := NewCommandBackend(CommandSpec{}); err == nil {
		t.Fatal("argv vacío debe fallar")
	}
	if _, err := NewCommandBackend(CommandSpec{Argv: []string{"bash", "-c", "id"}}); err == nil {
		t.Fatal("intérprete de shell debe ser rechazado por seguridad")
	}
	if _, err := NewCommandBackend(CommandSpec{Argv: []string{"/bin/ls"}}); err == nil {
		t.Fatal("comando con ruta debe ser rechazado por seguridad")
	}
	if _, err := NewCommandBackend(CommandSpec{Argv: []string{"x"}, Format: "json"}); err == nil {
		t.Fatal("formato desconocido debe fallar")
	}
	if _, err := NewCommandBackend(CommandSpec{Argv: []string{"x", " "}}); err == nil {
		t.Fatal("argumento vacío debe fallar")
	}
}

func fakeLookPath(found ...string) LookPath {
	set := make(map[string]bool, len(found))
	for _, name := range found {
		set[name] = true
	}
	return func(name string) (string, error) {
		if set[name] {
			return "/usr/bin/" + name, nil
		}
		return "", exec.ErrNotFound
	}
}

func ids(backends []Backend) []string {
	out := make([]string, len(backends))
	for i, b := range backends {
		out[i] = b.ID()
	}
	return out
}

func TestDetectPrefersFirstSystemBackend(t *testing.T) {
	d := &Detector{LookPath: fakeLookPath("checkupdates", "pacman", "paru", "flatpak"), DistroBase: "arch"}
	got := ids(d.Detect())
	want := []string{"pacman", "aur", "flatpak"}
	if !sameStrings(got, want) {
		t.Fatalf("detectados = %v, quiero %v", got, want)
	}
}

func TestDetectDNF(t *testing.T) {
	d := &Detector{LookPath: fakeLookPath("dnf", "flatpak"), DistroBase: "fedora"}
	got := ids(d.Detect())
	want := []string{"dnf", "flatpak"}
	if !sameStrings(got, want) {
		t.Fatalf("detectados = %v, quiero %v", got, want)
	}
}

func TestDetectAPT(t *testing.T) {
	d := &Detector{LookPath: fakeLookPath("apt", "flatpak"), DistroBase: "debian"}
	got := ids(d.Detect())
	want := []string{"apt", "flatpak"}
	if !sameStrings(got, want) {
		t.Fatalf("detectados = %v, quiero %v", got, want)
	}
}

func TestDetectXBPSWithYay(t *testing.T) {
	d := &Detector{LookPath: fakeLookPath("xbps-install", "yay"), DistroBase: "void"}
	got := ids(d.Detect())
	want := []string{"xbps", "aur"}
	if !sameStrings(got, want) {
		t.Fatalf("detectados = %v, quiero %v", got, want)
	}
}

func TestDetectFlatpakOnly(t *testing.T) {
	d := &Detector{LookPath: fakeLookPath("flatpak")}
	got := ids(d.Detect())
	want := []string{"flatpak"}
	if !sameStrings(got, want) {
		t.Fatalf("detectados = %v, quiero %v", got, want)
	}
}

func TestPrivileged(t *testing.T) {
	got := privileged(fakeLookPath("pkexec", "sudo"), "pacman", "-Syu")
	if !sameStrings(got, []string{"pkexec", "pacman", "-Syu"}) {
		t.Fatalf("con pkexec = %v", got)
	}
	got = privileged(fakeLookPath("sudo"), "pacman", "-Syu")
	if !sameStrings(got, []string{"sudo", "-n", "pacman", "-Syu"}) {
		t.Fatalf("con sudo = %v", got)
	}
	got = privileged(fakeLookPath(), "pacman", "-Syu")
	if !sameStrings(got, []string{"pacman", "-Syu"}) {
		t.Fatalf("sin privilegios = %v", got)
	}
}
