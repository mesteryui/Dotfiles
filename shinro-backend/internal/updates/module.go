package updates

import (
	"context"
	"fmt"
	"slices"
	"strings"
	"sync"
	"time"

	"shinro-backend/internal/safe"
)

// Config es la configuración que envía el cliente en el hello.
type Config struct {
	// Backends es la lista de IDs que quiere el cliente. Vacía = sistema +
	// AUR; "all" = todos los detectados (incluido Flatpak); o una lista
	// explícita: ["pacman", "aur", "flatpak"].
	Backends []string

	// Command configura el backend genérico para gestores no soportados.
	Command *CommandSpec
}

// State es el estado compartido que se envía por el socket.
type State struct {
	Count           int            `json:"count"`
	Packages        []Package      `json:"packages"`
	Checking        bool           `json:"checking"`
	CheckedAt       int64          `json:"checked_at"`
	Errors          []BackendError `json:"errors"`
	Updating        bool           `json:"updating"`
	UpdatingBackend string         `json:"updating_backend,omitempty"`
	LastUpdateAt    int64          `json:"last_update_at"`
	CanUpdate       bool           `json:"can_update"`
	Backends        []string       `json:"backends"`
	// UpdateScript es el comando (o comandos unidos con &&) que el frontend
	// debe ejecutar en un terminal interactivo para actualizar. Lo decide
	// el backend según los backends detectados; se quitan las banderas de
	// confirmación automática para que el usuario confirme.
	UpdateScript    string         `json:"update_script,omitempty"`
}

// Module mantiene el estado de actualizaciones en RAM.
//
// No hay persistencia a propósito: tras reiniciar, checked_at vuelve a 0 y la
// UI muestra "—" hasta la primera comprobación. La comprobación no depende de
// comprobaciones anteriores; solo de si hay red.
type Module struct {
	mu        sync.Mutex
	executor  Executor
	online    func() bool
	available []Backend
	active    []Backend
	cfg       Config
	state     State

	checking  bool
	checkDone chan struct{}

	updating   bool
	updateDone chan struct{}

	broadcast func()
}

// New crea el módulo con los backends ya detectados.
//
// executor puede ser nil (se usa Runner); online puede ser nil (se asume que
// hay red). Los tests inyectan un Executor falso y una función de red simulada.
func New(backends []Backend, executor Executor, online func() bool) *Module {
	if executor == nil {
		executor = NewRunner()
	}
	if online == nil {
		online = func() bool { return true }
	}

	m := &Module{
		executor:  executor,
		online:    online,
		available: append([]Backend(nil), backends...),
		state: State{
			Packages: []Package{},
			Errors:   []BackendError{},
			Backends: []string{},
		},
	}
	m.active, _ = m.selectBackends(Config{})
	m.state.Backends = backendIDs(m.active)
	m.state.CanUpdate = canUpdate(m.active)
	m.state.UpdateScript = buildUpdateScript(m.active)
	return m
}

// SetBroadcast registra la función que empuja el estado a los clientes
// suscritos. La usa el módulo del socket para avisar sin polling.
func (m *Module) SetBroadcast(fn func()) {
	m.mu.Lock()
	m.broadcast = fn
	m.mu.Unlock()
}

// Snapshot devuelve una copia profunda del estado actual.
func (m *Module) Snapshot() State {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.snapshotLocked()
}

func (m *Module) snapshotLocked() State {
	s := m.state
	s.Packages = append([]Package(nil), m.state.Packages...)
	s.Errors = append([]BackendError(nil), m.state.Errors...)
	s.Backends = append([]string(nil), m.state.Backends...)
	return s
}

// Configure aplica la configuración del hello. Si cambia el conjunto de
// backends, descarta el estado anterior: los paquetes de un backend que ya no
// está activo no deben quedarse en la lista.
func (m *Module) Configure(cfg Config) {
	cfg = cloneConfig(cfg)

	active, configErrs := m.selectBackends(cfg)
	ids := backendIDs(active)
	canUpd := canUpdate(active)

	m.mu.Lock()
	oldIDs := append([]string(nil), m.state.Backends...)
	changed := !sameStrings(oldIDs, ids) ||
		!sameCommandSpec(m.cfg.Command, cfg.Command)

	m.cfg = cfg
	m.active = active
	m.state.Backends = ids
	m.state.CanUpdate = canUpd
	m.state.UpdateScript = buildUpdateScript(active)
	if changed {
		m.state.Packages = []Package{}
		m.state.Count = 0
		m.state.Errors = append([]BackendError(nil), configErrs...)
		m.state.CheckedAt = 0
	}
	m.mu.Unlock()

	if changed {
		m.notify()
	}
}

// Check ejecuta una comprobación completa.
//
// Sin red no ejecuta nada y devuelve el estado que hubiera. Una sola
// comprobación se comparte entre todos los clientes: los que llegan mientras
// hay una en curso esperan al mismo resultado.
func (m *Module) Check(ctx context.Context) State {
	if !m.isOnline() {
		return m.Snapshot()
	}

	// No comprobar mientras se está actualizando: pacman y checkupdates
	// comparten la base de datos y se estorbarían.
	m.waitForUpdate(ctx)
	if ctx.Err() != nil {
		return m.Snapshot()
	}

	m.mu.Lock()
	if m.checking {
		done := m.checkDone
		m.mu.Unlock()
		waitCtx(ctx, done)
		return m.Snapshot()
	}
	m.checking = true
	m.state.Checking = true
	done := make(chan struct{})
	m.checkDone = done
	active := append([]Backend(nil), m.active...)
	m.mu.Unlock()

	m.notify()

	finished := false
	defer func() {
		if r := recover(); r != nil {
			m.mu.Lock()
			m.state.Checking = false
			m.checking = false
			if m.checkDone == done {
				m.checkDone = nil
			}
			if !finished {
				close(done)
			}
			m.mu.Unlock()
			m.notify()
			panic(r)
		}
	}()

	packages, errs := m.runCheck(ctx, active)

	m.mu.Lock()
	m.state.Packages = packages
	m.state.Count = len(packages)
	m.state.Errors = errs
	m.state.CheckedAt = time.Now().Unix()
	m.state.Checking = false
	m.checking = false
	if m.checkDone == done {
		m.checkDone = nil
	}
	finished = true
	close(done)
	m.mu.Unlock()

	m.notify()
	return m.Snapshot()
}

// Update ejecuta los comandos de actualización de los backends activos, en
// orden. Un fallo en uno no impide intentar los demás. Al terminar refresca el
// contador con una comprobación real.
func (m *Module) Update(ctx context.Context) State {
	if !m.isOnline() {
		m.addError(BackendError{
			Backend: "network",
			Code:    -1,
			Message: "sin conexión a Internet",
		})
		return m.Snapshot()
	}

	m.waitForCheck(ctx)
	if ctx.Err() != nil {
		return m.Snapshot()
	}

	m.mu.Lock()
	if m.updating {
		done := m.updateDone
		m.mu.Unlock()
		waitCtx(ctx, done)
		return m.Snapshot()
	}
	m.updating = true
	m.state.Updating = true
	m.state.UpdatingBackend = ""
	done := make(chan struct{})
	m.updateDone = done
	active := append([]Backend(nil), m.active...)
	m.mu.Unlock()

	m.notify()

	finished := false
	defer func() {
		if r := recover(); r != nil {
			m.mu.Lock()
			m.state.Updating = false
			m.state.UpdatingBackend = ""
			m.updating = false
			if m.updateDone == done {
				m.updateDone = nil
			}
			if !finished {
				close(done)
			}
			m.mu.Unlock()
			m.notify()
			panic(r)
		}
	}()

	commands := buildUpdateCommands(active)
	var updateErrs []BackendError
	if len(commands) == 0 {
		updateErrs = append(updateErrs, BackendError{
			Backend: "updates",
			Code:    -1,
			Message: "ningún backend permite actualizar",
		})
	}

	for _, cmd := range commands {
		m.mu.Lock()
		m.state.UpdatingBackend = cmd.backend
		m.mu.Unlock()
		m.notify()

		out, err := m.executor.Run(ctx, cmd.argv)
		if err != nil {
			updateErrs = append(updateErrs, BackendError{
				Backend: cmd.backend,
				Code:    -1,
				Message: err.Error(),
			})
			continue
		}
		if out.Exit != 0 {
			msg := firstLine(out.Stderr)
			if msg == "" {
				msg = firstLine(out.Stdout)
			}
			if msg == "" {
				msg = fmt.Sprintf("exit %d", out.Exit)
			}
			updateErrs = append(updateErrs, BackendError{
				Backend: cmd.backend,
				Code:    out.Exit,
				Message: msg,
			})
		}
	}

	m.mu.Lock()
	m.state.Updating = false
	m.state.UpdatingBackend = ""
	m.state.LastUpdateAt = time.Now().Unix()
	m.updating = false
	if m.updateDone == done {
		m.updateDone = nil
	}
	finished = true
	close(done)
	m.mu.Unlock()
	m.notify()

	// Refrescar el contador. Se usa un contexto nuevo: si el cliente que
	// pidió la actualización se fue, la comprobación posterior sigue
	// teniendo sentido.
	state := m.Check(context.Background())

	// Los errores de actualización no deben desaparecer porque la
	// comprobación posterior haya ido bien. Se conservan hasta la próxima
	// comprobación periódica.
	if len(updateErrs) > 0 {
		m.mu.Lock()
		m.state.Errors = trimErrors(append(m.state.Errors, updateErrs...))
		m.mu.Unlock()
		m.notify()
		return m.Snapshot()
	}
	return state
}

// InvalidateCaches existe para que el servidor avise a los módulos online al
// recuperar la red. Este módulo no guarda caché persistente: cada Check
// ejecuta los backends de nuevo, así que no hay nada que descartar.
func (m *Module) InvalidateCaches() {}

// ---------------------------------------------------------------------------
// Interno
// ---------------------------------------------------------------------------

func (m *Module) isOnline() bool {
	return m.online == nil || m.online()
}

func (m *Module) waitForCheck(ctx context.Context) {
	m.mu.Lock()
	if !m.checking {
		m.mu.Unlock()
		return
	}
	done := m.checkDone
	m.mu.Unlock()
	waitCtx(ctx, done)
}

func (m *Module) waitForUpdate(ctx context.Context) {
	m.mu.Lock()
	if !m.updating {
		m.mu.Unlock()
		return
	}
	done := m.updateDone
	m.mu.Unlock()
	waitCtx(ctx, done)
}

func waitCtx(ctx context.Context, ch <-chan struct{}) {
	if ch == nil {
		return
	}
	select {
	case <-ch:
	case <-ctx.Done():
	}
}

func (m *Module) notify() {
	m.mu.Lock()
	fn := m.broadcast
	m.mu.Unlock()
	if fn != nil {
		fn()
	}
}

const maxErrors = 32

func trimErrors(errs []BackendError) []BackendError {
	if len(errs) <= maxErrors {
		return errs
	}
	return append([]BackendError(nil), errs[len(errs)-maxErrors:]...)
}

func (m *Module) addError(e BackendError) {
	m.mu.Lock()
	m.state.Errors = trimErrors(append(m.state.Errors, e))
	m.mu.Unlock()
	m.notify()
}

type execError struct {
	code int
	msg  string
}

func (e *execError) Error() string { return e.msg }

func (m *Module) runCheck(ctx context.Context, active []Backend) ([]Package, []BackendError) {
	// Los backends son independientes entre sí (por ejemplo, Flatpak no comparte
	// recursos con pacman/AUR), así que se comprueban en paralelo para reducir
	// el tiempo total de la comprobación de O(suma) a O(máximo).
	type result struct {
		pkgs []Package
		err  error
	}
	results := make([]result, len(active))

	var wg sync.WaitGroup
	for i, b := range active {
		wg.Add(1)
		go func(i int, b Backend) {
			defer wg.Done()
			pkgs, err := safe.DoValue("updates.check."+b.ID(), func() ([]Package, error) {
				return m.runBackend(ctx, b)
			})
			results[i] = result{pkgs: pkgs, err: err}
		}(i, b)
	}
	wg.Wait()

	var packages []Package
	var errs []BackendError
	for i, b := range active {
		r := results[i]
		packages = append(packages, r.pkgs...)
		if r.err == nil {
			continue
		}
		code := -1
		if ee, ok := r.err.(*execError); ok {
			code = ee.code
		}
		errs = append(errs, BackendError{
			Backend: b.ID(),
			Code:    code,
			Message: r.err.Error(),
		})
	}
	sortPackages(packages)
	if packages == nil {
		packages = []Package{}
	}
	if errs == nil {
		errs = []BackendError{}
	}
	return packages, errs
}

func (m *Module) runBackend(ctx context.Context, b Backend) ([]Package, error) {
	if mb, ok := b.(multiBackend); ok {
		var (
			outputs  []Output
			problems []error
		)
		for _, argv := range mb.Commands() {
			out, err := m.executor.Run(ctx, argv)
			if err != nil {
				problems = append(problems, err)
				continue
			}
			outputs = append(outputs, out)
		}
		pkgs, parseErr := mb.ParseMulti(outputs)
		if parseErr != nil {
			problems = append(problems, parseErr)
		}
		if len(problems) > 0 {
			return pkgs, &execError{code: -1, msg: joinErrors(problems).Error()}
		}
		return pkgs, nil
	}

	out, err := m.executor.Run(ctx, b.Command())
	if err != nil {
		return nil, err
	}
	pkgs, err := b.Parse(out.Stdout, out.Exit)
	if err != nil {
		msg := err.Error()
		if s := firstLine(out.Stderr); s != "" {
			msg = s
		}
		return pkgs, &execError{code: out.Exit, msg: msg}
	}
	return pkgs, nil
}

type updateCommand struct {
	backend string
	argv    []string
}

func buildUpdateCommands(active []Backend) []updateCommand {
	var out []updateCommand
	for _, b := range active {
		updater, ok := b.(Updater)
		if !ok {
			continue
		}
		for _, argv := range updater.UpdateCommands() {
			if len(argv) == 0 {
				continue
			}
			out = append(out, updateCommand{
				backend: b.ID(),
				argv:    append([]string(nil), argv...),
			})
		}
	}
	return out
}

// buildUpdateScript genera el comando (o comandos unidos con &&) que debe
// ejecutarse en un terminal interactivo para actualizar. Se eliminan las
// banderas de confirmación automática (--noconfirm, -y, --assumeyes) para
// que el usuario confirme manualmente.
func buildUpdateScript(active []Backend) string {
	cmds := buildUpdateCommands(active)
	var parts []string
	for _, c := range cmds {
		argv := stripAutoConfirm(c.argv)
		if len(argv) == 0 {
			continue
		}
		parts = append(parts, shellJoin(argv))
	}
	return strings.Join(parts, " && ")
}

// stripAutoConfirm elimina banderas de confirmación automática de un argv.
func stripAutoConfirm(argv []string) []string {
	out := make([]string, 0, len(argv))
	for _, a := range argv {
		switch strings.TrimSpace(a) {
		case "--noconfirm", "-y", "--assumeyes", "--yes":
			continue
		}
		out = append(out, a)
	}
	return out
}

// shellJoin une un argv en una cadena apta para `sh -c`, citando los
// argumentos que contengan espacios.
func shellJoin(argv []string) string {
	quoted := make([]string, 0, len(argv))
	for _, a := range argv {
		if strings.ContainsAny(a, " \t\n\"'") {
			quoted = append(quoted, "'"+strings.ReplaceAll(a, "'", "'\\''")+"'")
		} else {
			quoted = append(quoted, a)
		}
	}
	return strings.Join(quoted, " ")
}

func (m *Module) selectBackends(cfg Config) ([]Backend, []BackendError) {
	var errs []BackendError

	defaultSet := len(cfg.Backends) == 0
	all := contains(cfg.Backends, "all")
	explicit := make(map[string]bool, len(cfg.Backends))
	if !all {
		for _, id := range cfg.Backends {
			explicit[id] = true
		}
	}

	var out []Backend
	for _, b := range m.available {
		id := b.ID()
		include := false
		switch {
		case defaultSet:
			// Por defecto: gestor del sistema + AUR. Flatpak solo si el
			// cliente lo pide explícitamente, porque puede ser lento.
			include = isSystemBackend(id) || id == "aur"
		case all:
			include = true
		default:
			include = explicit[id]
		}
		if include {
			out = append(out, b)
		}
	}

	// Si no hay ningún backend por defecto (por ejemplo, solo Flatpak),
	// usar lo que haya en vez de quedarse sin comprobar nada.
	if defaultSet && len(out) == 0 {
		out = append(out, m.available...)
	}

	if cfg.Command != nil && (defaultSet || all || explicit["command"]) {
		b, err := NewCommandBackend(*cfg.Command)
		if err != nil {
			errs = append(errs, BackendError{
				Backend: "command",
				Code:    -1,
				Message: err.Error(),
			})
		} else {
			out = append(out, b)
		}
	}

	// Deduplicar por ID conservando el orden.
	seen := make(map[string]bool, len(out))
	deduped := out[:0]
	for _, b := range out {
		if seen[b.ID()] {
			continue
		}
		seen[b.ID()] = true
		deduped = append(deduped, b)
	}
	return deduped, errs
}

func canUpdate(active []Backend) bool {
	for _, b := range active {
		if u, ok := b.(Updater); ok && len(u.UpdateCommands()) > 0 {
			return true
		}
	}
	return false
}

func backendIDs(backends []Backend) []string {
	out := make([]string, 0, len(backends))
	for _, b := range backends {
		out = append(out, b.ID())
	}
	if out == nil {
		out = []string{}
	}
	return out
}

func contains(list []string, value string) bool {
	return slices.Contains(list, value)
}

func sameStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func sameCommandSpec(a, b *CommandSpec) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	return a.Format == b.Format && sameStrings(a.Argv, b.Argv)
}

func cloneConfig(cfg Config) Config {
	out := Config{
		Backends: append([]string(nil), cfg.Backends...),
	}
	if cfg.Command != nil {
		out.Command = &CommandSpec{
			Argv:   append([]string(nil), cfg.Command.Argv...),
			Format: cfg.Command.Format,
		}
	}
	return out
}
