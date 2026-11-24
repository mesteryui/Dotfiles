// Package updates comprueba y lista actualizaciones de paquetes.
//
// El paquete no sabe nada de la distribución ni de la shell: solo conoce
// backends (pacman, dnf, apt, xbps, AUR, Flatpak y un backend genérico
// `command`) y ejecuta sus comandos sin shell. La detección se hace por
// LookPath, nunca leyendo /etc/os-release.
package updates

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// Package es una actualización pendiente. El formato es común para todos los
// backends: la shell no necesita saber de qué gestor viene.
type Package struct {
	Name    string `json:"name"`
	Old     string `json:"old"`
	New     string `json:"new"`
	Backend string `json:"backend"`
}

// BackendError es un fallo de un backend concreto. Un backend que falla no
// oculta los paquetes de los demás.
type BackendError struct {
	Backend string `json:"backend"`
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// Output es el resultado de ejecutar un comando.
type Output struct {
	Stdout []byte
	Stderr []byte
	Exit   int
}

// Executor ejecuta un argv sin shell. Runner es la implementación real; los
// tests inyectan una implementación falsa.
type Executor interface {
	Run(ctx context.Context, argv []string) (Output, error)
}

// Backend es un gestor de paquetes.
//
// Command devuelve un argv fijo (nunca una cadena de shell) y Parse interpreta
// su stdout. El exit se pasa tal cual porque cada gestor usa códigos distintos
// para "hay actualizaciones" y "no hay actualizaciones".
type Backend interface {
	ID() string
	Command() []string
	Parse(stdout []byte, exit int) ([]Package, error)
}

// Updater es implementado por los backends que saben actualizar. Devuelve los
// argv que hay que ejecutar, en orden.
type Updater interface {
	UpdateCommands() [][]string
}

// multiBackend es implementado por backends que necesitan más de un comando
// para una sola comprobación (Flatpak consulta la instalación de usuario y la
// de sistema).
type multiBackend interface {
	Commands() [][]string
	ParseMulti(outputs []Output) ([]Package, error)
}

// CommandSpec configura el backend genérico `command` desde el hello.
//
//	{"argv": ["mi-gestor", "listar"], "format": "lines"}
//	{"argv": ["mi-gestor", "listar"], "format": "lines-versions"}
type CommandSpec struct {
	Argv   []string `json:"argv"`
	Format string   `json:"format"`
}

// LookPath es exec.LookPath, inyectable para los tests.
type LookPath func(string) (string, error)

// Detector autodetecta los backends disponibles.
//
// El gestor de paquetes del SISTEMA se elige según la distro base (leyendo
// /etc/os-release: ID e ID_LIKE), no por LookPath: en una distro base Arch
// se usa pacman (y AUR si hay helper), en Fedora dnf, en Debian/Ubuntu apt,
// en Void xbps. Flatpak se añade siempre que esté instalado, porque es
// transversal. AUR solo tiene sentido en el ecosistema Arch.
//
// LookPath sigue usándose para comprobar que el binario existe y para los
// helpers (paru/yay). Si no se puede determinar la distro base, se cae al
// comportamiento anterior (detección por LookPath) para no perder cobertura.
type Detector struct {
	LookPath LookPath

	// DistroBase fuerza la distro base ("arch", "fedora", "debian", "void").
	// Vacío = leer /etc/os-release.
	DistroBase string

	// ReadOSRelease permite inyectar la lectura de /etc/os-release en tests.
	// Devuelve id e idLike. Nil = leer el fichero real.
	ReadOSRelease func() (string, string, error)
}

// NewDetector crea un detector que usa exec.LookPath y lee /etc/os-release.
func NewDetector() *Detector {
	return &Detector{LookPath: exec.LookPath}
}

func (d *Detector) has(name string) bool {
	if d == nil || d.LookPath == nil {
		return false
	}
	_, err := d.LookPath(name)
	return err == nil
}

// distroBase devuelve la distro base normalizada: "arch", "fedora", "debian",
// "void" o "" si no se pudo determinar.
func (d *Detector) distroBase() string {
	if d != nil && d.DistroBase != "" {
		return normalizeDistroBase(d.DistroBase)
	}
	read := d.readOSRelease
	if read == nil {
		read = readOSReleaseFile
	}
	id, idLike, err := read()
	if err != nil {
		return ""
	}
	for _, token := range append([]string{id}, strings.Fields(idLike)...) {
		switch normalizeDistroBase(token) {
		case "arch":
			return "arch"
		case "fedora":
			return "fedora"
		case "debian":
			return "debian"
		case "void":
			return "void"
		}
	}
	return ""
}

func (d *Detector) readOSRelease() (string, string, error) {
	if d != nil && d.ReadOSRelease != nil {
		return d.ReadOSRelease()
	}
	return readOSReleaseFile()
}

func readOSReleaseFile() (string, string, error) {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return "", "", err
	}
	var id, idLike string
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		val = strings.Trim(val, "\"'")
		switch strings.TrimSpace(key) {
		case "ID":
			id = strings.ToLower(strings.TrimSpace(val))
		case "ID_LIKE":
			idLike = strings.ToLower(strings.TrimSpace(val))
		}
	}
	return id, idLike, nil
}

func normalizeDistroBase(name string) string {
	name = strings.ToLower(strings.TrimSpace(name))
	switch name {
	case "arch", "archlinux", "cachyos", "manjaro", "endeavouros", "garuda", "artix":
		return "arch"
	case "fedora", "rhel", "centos", "rocky", "almalinux", "opensuse", "suse", "nobara":
		return "fedora"
	case "debian", "ubuntu", "linuxmint", "mint", "pop", "popos", "kali", "raspbian", "devuan", "mx":
		return "debian"
	case "void":
		return "void"
	}
	return name
}

// Detect devuelve los backends disponibles, en orden de preferencia.
//
// El gestor de sistema se elige según la distro base. AUR se añade solo en
// el ecosistema Arch si hay un helper (paru/yay). Flatpak se añade si está
// instalado. El cliente decide después cuáles activa con `updates.backends`.
func (d *Detector) Detect() []Backend {
	var out []Backend
	base := d.distroBase()

	addSystem := func() {
		switch base {
		case "arch", "":
			// "" = desconocido: mantener la detección por LookPath anterior.
			switch {
			case d.has("checkupdates"):
				out = append(out, newPacman(d.LookPath, "checkupdates"))
			case d.has("pacman"):
				out = append(out, newPacman(d.LookPath, "pacman"))
			}
			if base == "" {
				// Fallback para distro desconocida: probar el resto.
				if len(out) == 0 {
					switch {
					case d.has("dnf"):
						out = append(out, newDNF(d.LookPath))
					case d.has("apt"):
						out = append(out, newAPT(d.LookPath))
					case d.has("xbps-install"):
						out = append(out, newXBPS(d.LookPath))
					}
				}
			}
		case "fedora":
			if d.has("dnf") {
				out = append(out, newDNF(d.LookPath))
			}
		case "debian":
			if d.has("apt") {
				out = append(out, newAPT(d.LookPath))
			}
		case "void":
			if d.has("xbps-install") {
				out = append(out, newXBPS(d.LookPath))
			}
		}
	}
	addSystem()

	// AUR se añade si hay un helper disponible (paru/yay), igual que antes:
	// es el usuario quien decide si instalarlo, y solo funciona en su
	// ecosistema, pero su presencia ya implica que tiene sentido.
	if helper := aurHelper(d); helper != "" {
		out = append(out, newAUR(d.LookPath, helper))
	}

	if d.has("flatpak") {
		out = append(out, newFlatpak(d.LookPath))
	}

	return out
}

func aurHelper(d *Detector) string {
	for _, helper := range []string{"paru", "yay"} {
		if d.has(helper) {
			return helper
		}
	}
	return ""
}

// systemIDs son los gestores que representan al sistema operativo. Solo se
// activa uno de ellos (el primero detectado).
var systemIDs = map[string]bool{
	"pacman": true,
	"dnf":    true,
	"apt":    true,
	"xbps":   true,
}

// isSystemBackend indica si el backend gestiona los paquetes del sistema.
func isSystemBackend(id string) bool {
	return systemIDs[id]
}

// ---------------------------------------------------------------------------
// Utilidades de parseo
// ---------------------------------------------------------------------------

var (
	ansiRE    = regexp.MustCompile("\x1b\\[[0-9;?]*[ -/]*[@-~]")
	nameRE    = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9@._+:~-]*$`)
	aptLineRE = regexp.MustCompile(`^([^/\s]+)/\S+\s+(\S+)\s+\S+(?:\s+\[upgradable from:\s*([^\]]+)\])?`)
)

// validName valida un nombre de paquete antes de aceptarlo. Evita que una
// salida rara (o maliciosa) meta texto arbitrario en la UI.
func validName(name string) bool {
	return name != "" && len(name) <= 255 && nameRE.MatchString(name)
}

// cleanVersion limpia una versión de control chars y la acota.
func cleanVersion(v string) string {
	v = strings.TrimSpace(v)
	v = strings.Map(func(r rune) rune {
		if r < 0x20 || r == 0x7f {
			return -1
		}
		return r
	}, v)
	if len(v) > 128 {
		v = v[:128]
	}
	return v
}

// cleanLines separa la salida en líneas limpias, sin ANSI ni \r.
func cleanLines(stdout []byte) []string {
	raw := strings.Split(string(stdout), "\n")
	out := make([]string, 0, len(raw))
	for _, line := range raw {
		line = strings.TrimSpace(ansiRE.ReplaceAllString(line, ""))
		line = strings.TrimSuffix(line, "\r")
		if line != "" {
			out = append(out, line)
		}
	}
	return out
}

// parseArrowLines interpreta el formato compartido por pacman, checkupdates,
// paru y yay: `nombre version_vieja -> version_nueva`. yay añade un sufijo
// `[1h15m]` que se descarta.
func parseArrowLines(stdout []byte, backend string) []Package {
	var out []Package
	for _, line := range cleanLines(stdout) {
		before, after, ok := strings.Cut(line, " -> ")
		if !ok {
			continue
		}
		left := strings.TrimSpace(before)
		right := strings.TrimSpace(after)

		// yay: "paquete 1.0 -> 1.1 [1h15m]"
		if i := strings.LastIndex(right, " ["); i >= 0 && strings.HasSuffix(right, "]") {
			right = strings.TrimSpace(right[:i])
		}

		fields := strings.Fields(left)
		if len(fields) < 2 {
			continue
		}
		name := fields[0]
		old := strings.Join(fields[1:], " ")
		if !validName(name) {
			continue
		}
		out = append(out, Package{
			Name:    name,
			Old:     cleanVersion(old),
			New:     cleanVersion(right),
			Backend: backend,
		})
	}
	return out
}

// firstLine devuelve la primera línea no vacía de un texto, para los mensajes
// de error.
func firstLine(b []byte) string {
	for _, line := range cleanLines(b) {
		return line
	}
	return ""
}

func joinErrors(errs []error) error {
	parts := make([]string, 0, len(errs))
	for _, err := range errs {
		if err != nil {
			parts = append(parts, err.Error())
		}
	}
	if len(parts) == 0 {
		return nil
	}
	return fmt.Errorf("%s", strings.Join(parts, "; "))
}

// sortPackages ordena el resultado para que la UI sea estable entre
// comprobaciones y entre backends.
func sortPackages(pkgs []Package) {
	sort.SliceStable(pkgs, func(i, j int) bool {
		if pkgs[i].Backend != pkgs[j].Backend {
			return pkgs[i].Backend < pkgs[j].Backend
		}
		return pkgs[i].Name < pkgs[j].Name
	})
}

// ---------------------------------------------------------------------------
// Backend genérico `command`
// ---------------------------------------------------------------------------

type commandBackend struct {
	argv   []string
	format string
}

func isSafeCommandName(name string) bool {
	name = strings.TrimSpace(name)
	if name == "" {
		return false
	}
	if strings.ContainsAny(name, "/\\") {
		return false
	}
	base := strings.ToLower(filepath.Base(name))
	switch base {
	case "sh", "bash", "zsh", "csh", "tcsh", "dash", "ksh", "fish", "nu", "pwsh",
		"python", "python2", "python3", "perl", "ruby", "php", "lua",
		"node", "nodejs", "deno", "bun", "gjs", "guile", "tclsh", "wish", "expect",
		"curl", "wget", "nc", "netcat", "ncat", "socat", "telnet", "ssh", "scp", "rsync",
		"env", "sudo", "pkexec", "su", "doas", "chroot", "nsenter", "systemd-run",
		"docker", "podman", "kubectl", "crictl",
		"xargs", "find", "awk", "gawk", "mawk", "nawk", "sed",
		"rm", "dd", "mkfs", "fdisk", "parted", "chmod", "chown", "mv", "cp":
		return false
	}
	for _, prefix := range []string{"python", "perl", "ruby", "php", "lua", "node"} {
		if strings.HasPrefix(base, prefix) {
			return false
		}
	}
	return true
}

// ValidateCommandArgv comprueba que un comando no intente inyecciones de shell
// ni llamadas a intérpretes arbitrarios por seguridad.
func ValidateCommandArgv(argv []string) error {
	if len(argv) == 0 || strings.TrimSpace(argv[0]) == "" {
		return fmt.Errorf("argv vacío")
	}
	if !isSafeCommandName(argv[0]) {
		return fmt.Errorf("comando %q no permitido por motivos de seguridad", argv[0])
	}
	for _, arg := range argv {
		if strings.ContainsAny(arg, "\x00\r\n") {
			return fmt.Errorf("argumento contiene caracteres de control no permitidos")
		}
	}
	return nil
}

// NewCommandBackend valida y crea el backend genérico. El argv es fijo y se
// ejecuta sin shell; el formato decide cómo interpretar el stdout.
func NewCommandBackend(spec CommandSpec) (Backend, error) {
	if err := ValidateCommandArgv(spec.Argv); err != nil {
		return nil, fmt.Errorf("updates.command: %w", err)
	}
	format := strings.TrimSpace(spec.Format)
	if format == "" {
		format = "lines"
	}
	if format != "lines" && format != "lines-versions" {
		return nil, fmt.Errorf("updates.command: formato desconocido %q (usa lines o lines-versions)", spec.Format)
	}
	argv := append([]string(nil), spec.Argv...)
	for i := range argv {
		argv[i] = strings.TrimSpace(argv[i])
		if argv[i] == "" {
			return nil, fmt.Errorf("updates.command: argumento vacío en argv")
		}
	}
	return &commandBackend{argv: argv, format: format}, nil
}

func (b *commandBackend) ID() string { return "command" }

func (b *commandBackend) Command() []string { return append([]string(nil), b.argv...) }

func (b *commandBackend) Parse(stdout []byte, exit int) ([]Package, error) {
	if exit != 0 {
		return nil, fmt.Errorf("exit %d", exit)
	}

	switch b.format {
	case "lines":
		var out []Package
		for _, line := range cleanLines(stdout) {
			if !validName(line) {
				continue
			}
			out = append(out, Package{Name: line, Backend: b.ID()})
		}
		return out, nil

	case "lines-versions":
		return parseLinesVersions(stdout, b.ID()), nil
	}
	return nil, fmt.Errorf("formato desconocido %q", b.format)
}

// parseLinesVersions acepta tanto `nombre vieja -> nueva` como
// `nombre vieja nueva`, incluso mezclados en la misma salida.
func parseLinesVersions(stdout []byte, backend string) []Package {
	var out []Package
	for _, line := range cleanLines(stdout) {
		if before, after, ok := strings.Cut(line, " -> "); ok {
			left := strings.TrimSpace(before)
			right := strings.TrimSpace(after)
			if i := strings.LastIndex(right, " ["); i >= 0 && strings.HasSuffix(right, "]") {
				right = strings.TrimSpace(right[:i])
			}
			fields := strings.Fields(left)
			if len(fields) < 2 {
				continue
			}
			name := fields[0]
			if !validName(name) {
				continue
			}
			out = append(out, Package{
				Name:    name,
				Old:     cleanVersion(strings.Join(fields[1:], " ")),
				New:     cleanVersion(right),
				Backend: backend,
			})
			continue
		}

		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		name := fields[0]
		if !validName(name) {
			continue
		}
		out = append(out, Package{
			Name:    name,
			Old:     cleanVersion(fields[1]),
			New:     cleanVersion(strings.Join(fields[2:], " ")),
			Backend: backend,
		})
	}
	return out
}
