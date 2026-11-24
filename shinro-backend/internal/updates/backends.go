package updates

import (
	"fmt"
	"strings"
)

// ---------------------------------------------------------------------------
// pacman / checkupdates
// ---------------------------------------------------------------------------

type pacmanBackend struct {
	lookPath LookPath
	command  []string
	okExit   map[int]bool
}

func newPacman(lookPath LookPath, mode string) Backend {
	b := &pacmanBackend{lookPath: lookPath}
	if mode == "checkupdates" {
		// checkupdates sincroniza una base de datos temporal y no toca la
		// del sistema. --nocolor evita ANSI en el stdout.
		b.command = []string{"checkupdates", "--nocolor"}
		b.okExit = map[int]bool{0: true, 2: true}
	} else {
		// Sin checkupdates, pacman -Qu compara contra la base local. No
		// descarga nada, pero sirve como respaldo.
		b.command = []string{"pacman", "-Qu"}
		b.okExit = map[int]bool{0: true, 1: true}
	}
	return b
}

func (b *pacmanBackend) ID() string { return "pacman" }

func (b *pacmanBackend) Command() []string { return append([]string(nil), b.command...) }

func (b *pacmanBackend) Parse(stdout []byte, exit int) ([]Package, error) {
	if !b.okExit[exit] {
		return nil, fmt.Errorf("exit %d", exit)
	}
	return parseArrowLines(stdout, b.ID()), nil
}

func (b *pacmanBackend) UpdateCommands() [][]string {
	return [][]string{privileged(b.lookPath, "pacman", "-Syu", "--noconfirm")}
}

// ---------------------------------------------------------------------------
// AUR (paru / yay)
// ---------------------------------------------------------------------------

type aurBackend struct {
	lookPath LookPath
	helper   string
}

func newAUR(lookPath LookPath, helper string) Backend {
	return &aurBackend{lookPath: lookPath, helper: helper}
}

func (b *aurBackend) ID() string { return "aur" }

func (b *aurBackend) Command() []string {
	return []string{b.helper, "-Qua"}
}

func (b *aurBackend) Parse(stdout []byte, exit int) ([]Package, error) {
	// 0 = hay actualizaciones; 1 = no hay ninguna.
	if exit != 0 && exit != 1 {
		return nil, fmt.Errorf("exit %d", exit)
	}
	return parseArrowLines(stdout, b.ID()), nil
}

func (b *aurBackend) UpdateCommands() [][]string {
	// -Sua actualiza solo paquetes AUR: los del sistema los lleva pacman.
	// No se antepone pkexec: compilar AUR como root no es seguro. Si sudo
	// necesita contraseña, el comando fallará y se reportará el error.
	return [][]string{{b.helper, "-Sua", "--noconfirm"}}
}

// ---------------------------------------------------------------------------
// Flatpak
// ---------------------------------------------------------------------------

type flatpakBackend struct {
	lookPath LookPath
}

func newFlatpak(lookPath LookPath) Backend {
	return &flatpakBackend{lookPath: lookPath}
}

func (b *flatpakBackend) ID() string { return "flatpak" }

// Command devuelve la consulta de la instalación de sistema. La comprobación
// real usa Commands(), que consulta también la de usuario.
func (b *flatpakBackend) Command() []string {
	return flatpakCheckCommand("--system")
}

func flatpakCheckCommand(installation string) []string {
	return []string{
		"flatpak", "remote-ls", installation, "--updates",
		"--columns=application,version,branch,origin",
	}
}

func (b *flatpakBackend) Commands() [][]string {
	return [][]string{
		flatpakCheckCommand("--system"),
		flatpakCheckCommand("--user"),
	}
}

func (b *flatpakBackend) Parse(stdout []byte, exit int) ([]Package, error) {
	if exit != 0 {
		return nil, fmt.Errorf("exit %d", exit)
	}
	return parseFlatpak(stdout), nil
}

func (b *flatpakBackend) ParseMulti(outputs []Output) ([]Package, error) {
	var (
		packages []Package
		problems []error
		seen     = make(map[string]bool)
	)
	for _, out := range outputs {
		if out.Exit != 0 {
			problems = append(problems, fmt.Errorf("exit %d%s", out.Exit, suffix(firstLine(out.Stderr))))
			continue
		}
		for _, p := range parseFlatpak(out.Stdout) {
			key := p.Name + "\x00" + p.New
			if seen[key] {
				continue
			}
			seen[key] = true
			packages = append(packages, p)
		}
	}
	if len(packages) == 0 && len(problems) > 0 {
		return nil, joinErrors(problems)
	}
	return packages, joinErrors(problems)
}

func (b *flatpakBackend) UpdateCommands() [][]string {
	// flatpak elige la instalación por defecto. Si hace falta autenticación
	// de sistema, flatpak la pide por polkit.
	return [][]string{{"flatpak", "update", "-y"}}
}

// parseFlatpak interpreta la salida de remote-ls con
// --columns=application,version,branch,origin. Flatpak separa con tabulador;
// también se aceptan espacios por si cambia el formato.
func parseFlatpak(stdout []byte) []Package {
	var out []Package
	for _, line := range cleanLines(stdout) {
		var fields []string
		if strings.Contains(line, "\t") {
			fields = strings.Split(line, "\t")
		} else {
			fields = strings.Fields(line)
		}
		if len(fields) < 2 {
			continue
		}
		name := strings.TrimSpace(fields[0])
		if !validName(name) {
			continue
		}
		out = append(out, Package{
			Name:    name,
			New:     cleanVersion(fields[1]),
			Backend: "flatpak",
		})
	}
	return out
}

// ---------------------------------------------------------------------------
// dnf
// ---------------------------------------------------------------------------

type dnfBackend struct {
	lookPath LookPath
}

func newDNF(lookPath LookPath) Backend {
	return &dnfBackend{lookPath: lookPath}
}

func (b *dnfBackend) ID() string { return "dnf" }

func (b *dnfBackend) Command() []string {
	return []string{"dnf", "-q", "check-update"}
}

func (b *dnfBackend) Parse(stdout []byte, exit int) ([]Package, error) {
	// dnf usa 100 para "hay actualizaciones", 0 para "no hay" y 1 para error.
	if exit != 0 && exit != 100 {
		return nil, fmt.Errorf("exit %d", exit)
	}
	return parseDNF(stdout), nil
}

func (b *dnfBackend) UpdateCommands() [][]string {
	return [][]string{privileged(b.lookPath, "dnf", "upgrade", "-y")}
}

func parseDNF(stdout []byte) []Package {
	var out []Package
	for _, line := range cleanLines(stdout) {
		lower := strings.ToLower(line)
		skip := false
		for _, prefix := range []string{
			"last metadata", "obsoleting", "security:", "bugfix:",
			"enhancement:", "new security", "dependencies resolved",
			"package ", "arch ", "name ", "version ", "repo ",
			"installed", "available", "---",
		} {
			if strings.HasPrefix(lower, prefix) {
				skip = true
				break
			}
		}
		if skip {
			continue
		}

		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		name := stripArch(fields[0])
		if !validName(name) {
			continue
		}
		out = append(out, Package{
			Name:    name,
			New:     cleanVersion(fields[1]),
			Backend: "dnf",
		})
	}
	return out
}

func stripArch(name string) string {
	for _, arch := range []string{
		".x86_64", ".i686", ".i586", ".i386", ".noarch", ".aarch64",
		".armv7hl", ".armv6hl", ".ppc64le", ".s390x", ".riscv64",
	} {
		if before, ok := strings.CutSuffix(name, arch); ok {
			return before
		}
	}
	return name
}

// ---------------------------------------------------------------------------
// apt
// ---------------------------------------------------------------------------

type aptBackend struct {
	lookPath LookPath
	updater  string
}

func newAPT(lookPath LookPath) Backend {
	updater := "apt-get"
	if lookPath != nil {
		if _, err := lookPath("apt-get"); err != nil {
			updater = "apt"
		}
	}
	return &aptBackend{lookPath: lookPath, updater: updater}
}

func (b *aptBackend) ID() string { return "apt" }

func (b *aptBackend) Command() []string {
	return []string{"apt", "list", "--upgradable"}
}

func (b *aptBackend) Parse(stdout []byte, exit int) ([]Package, error) {
	if exit != 0 {
		return nil, fmt.Errorf("exit %d", exit)
	}
	return parseAPT(stdout), nil
}

func (b *aptBackend) UpdateCommands() [][]string {
	return [][]string{
		privileged(b.lookPath, b.updater, "update"),
		privileged(b.lookPath, b.updater, "upgrade", "-y"),
	}
}

func parseAPT(stdout []byte) []Package {
	var out []Package
	for _, line := range cleanLines(stdout) {
		if strings.HasPrefix(line, "Listing...") {
			continue
		}
		m := aptLineRE.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		name := m[1]
		if !validName(name) {
			continue
		}
		out = append(out, Package{
			Name:    name,
			Old:     cleanVersion(m[3]),
			New:     cleanVersion(m[2]),
			Backend: "apt",
		})
	}
	return out
}

// ---------------------------------------------------------------------------
// xbps (Void Linux)
// ---------------------------------------------------------------------------

type xbpsBackend struct {
	lookPath LookPath
}

func newXBPS(lookPath LookPath) Backend {
	return &xbpsBackend{lookPath: lookPath}
}

func (b *xbpsBackend) ID() string { return "xbps" }

func (b *xbpsBackend) Command() []string {
	return []string{"xbps-install", "-un"}
}

func (b *xbpsBackend) Parse(stdout []byte, exit int) ([]Package, error) {
	if exit != 0 {
		return nil, fmt.Errorf("exit %d", exit)
	}
	return parseXBPS(stdout), nil
}

func (b *xbpsBackend) UpdateCommands() [][]string {
	return [][]string{privileged(b.lookPath, "xbps-install", "-Syu", "-y")}
}

func parseXBPS(stdout []byte) []Package {
	var out []Package
	for _, line := range cleanLines(stdout) {
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}
		// Cabecera: Name Action Version New version Download size
		if strings.EqualFold(fields[0], "Name") || strings.EqualFold(fields[1], "Action") {
			continue
		}
		if !strings.EqualFold(fields[1], "update") {
			continue
		}
		name := fields[0]
		if !validName(name) {
			continue
		}
		out = append(out, Package{
			Name:    name,
			Old:     cleanVersion(fields[2]),
			New:     cleanVersion(fields[3]),
			Backend: "xbps",
		})
	}
	return out
}

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

// privileged antepone pkexec (polkit) o sudo -n cuando hace falta root. Si no
// hay ninguno, deja el argv tal cual: el comando fallará con un error claro en
// vez de colgarse esperando una contraseña que nadie puede teclear.
func privileged(lookPath LookPath, argv ...string) []string {
	if lookPath != nil {
		if _, err := lookPath("pkexec"); err == nil {
			return append([]string{"pkexec"}, argv...)
		}
		if _, err := lookPath("sudo"); err == nil {
			return append([]string{"sudo", "-n"}, argv...)
		}
	}
	return append([]string(nil), argv...)
}

func suffix(s string) string {
	if s == "" {
		return ""
	}
	return ": " + s
}

// compilo-check de que todos los backends implementan Backend.
var (
	_ Backend = (*pacmanBackend)(nil)
	_ Backend = (*aurBackend)(nil)
	_ Backend = (*flatpakBackend)(nil)
	_ Backend = (*dnfBackend)(nil)
	_ Backend = (*aptBackend)(nil)
	_ Backend = (*xbpsBackend)(nil)
	_ Backend = (*commandBackend)(nil)

	_ Updater = (*pacmanBackend)(nil)
	_ Updater = (*aurBackend)(nil)
	_ Updater = (*flatpakBackend)(nil)
	_ Updater = (*dnfBackend)(nil)
	_ Updater = (*aptBackend)(nil)
	_ Updater = (*xbpsBackend)(nil)
)
