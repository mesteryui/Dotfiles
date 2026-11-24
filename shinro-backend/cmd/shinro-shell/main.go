package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"maps"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"shinro-backend/internal/ipc"
)


// sockPath devuelve la ruta del socket Unix del backend.
func sockPath() string {
	p, err := ipc.DefaultSocketPath()
	if err != nil {
		// No hay directorio runtime de confianza. Se devuelve "" y el
		// llamador reportará el error.
		return ""
	}
	return p
}

// sendCommand envía una línea al backend y devuelve la respuesta.
func sendCommand(line string) (string, error) {
	path := sockPath()
	if path == "" {
		return "", fmt.Errorf("no se pudo resolver el socket del backend (XDG_RUNTIME_DIR no disponible)")
	}
	connection, err := net.DialTimeout("unix", path, 3*time.Second)
	if err != nil {
		return "", fmt.Errorf("daemon no alcanzable en %s (¿está shinro-backend ejecutándose?)", sockPath())
	}
	defer connection.Close()

	_ = connection.SetDeadline(time.Now().Add(10 * time.Second))
	if _, err := fmt.Fprintln(connection, line); err != nil {
		return "", err
	}

	reader := bufio.NewReader(connection)
	resp, err := reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("sin respuesta del daemon: %v", err)
	}
	return strings.TrimSpace(resp), nil
}

// callModule construye un mensaje JSON para un módulo y lo envía al backend.
func callModule(module string, extra map[string]any) (string, error) {
	payload := map[string]any{"type": "get", "module": module}
	maps.Copy(payload, extra)
	b, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return sendCommand(string(b))
}

// printJSON imprime una respuesta JSON con indentación legible.
func printJSON(raw string) {
	var v any
	if err := json.Unmarshal([]byte(raw), &v); err != nil {
		fmt.Println(raw)
		return
	}
	b, _ := json.MarshalIndent(v, "", "  ")
	fmt.Println(string(b))
}

// usage imprime la ayuda general.
func usage() {
	fmt.Fprintln(os.Stderr, "uso: shinro-shell <comando> [argumentos]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Comandos disponibles:")
	fmt.Fprintln(os.Stderr, "  status                 resumen del sistema (CPU, RAM, disco, batería)")
	fmt.Fprintln(os.Stderr, "  ping                   comprueba que el backend responde")
	fmt.Fprintln(os.Stderr, "  updates [check]        lista o comprueba actualizaciones")
	fmt.Fprintln(os.Stderr, "  files <texto>          búsqueda difusa de archivos en $HOME")
	fmt.Fprintln(os.Stderr, "  clipboard <acción>     gestiona el historial del portapapeles")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Ejemplos:")
	fmt.Fprintln(os.Stderr, "  shinro-shell status")
	fmt.Fprintln(os.Stderr, "  shinro-shell updates")
	fmt.Fprintln(os.Stderr, "  shinro-shell updates check")
	fmt.Fprintln(os.Stderr, "  shinro-shell files documento")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard list")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Usa 'shinro-shell <comando> --help' para ayuda de un comando específico.")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Variables de entorno:")
	fmt.Fprintln(os.Stderr, "  SHINRO_SOCKET_PATH  ruta del socket Unix (por defecto $XDG_RUNTIME_DIR/shinro)")
}

// usageStatus imprime la ayuda del comando status.
func usageStatus() {
	fmt.Fprintln(os.Stderr, "uso: shinro-shell status")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Descripción:")
	fmt.Fprintln(os.Stderr, "  Muestra un resumen del estado del sistema: CPU, RAM, disco,")
	fmt.Fprintln(os.Stderr, "  red, temperatura y tiempo de actividad.")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Ejemplo:")
	fmt.Fprintln(os.Stderr, "  shinro-shell status")
}

// usagePing imprime la ayuda del comando ping.
func usagePing() {
	fmt.Fprintln(os.Stderr, "uso: shinro-shell ping [--json]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Descripción:")
	fmt.Fprintln(os.Stderr, "  Comprueba que el backend responde y devuelve su estado de salud:")
	fmt.Fprintln(os.Stderr, "  estado de cada módulo (último envío, errores, duración media),")
	fmt.Fprintln(os.Stderr, "  datos del daemon (uptime, goroutines, memoria, clientes) y la lista")
	fmt.Fprintln(os.Stderr, "  de problemas y de cosas que se podrían mejorar.")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Opciones:")
	fmt.Fprintln(os.Stderr, "  --json    muestra el informe en JSON en vez del resumen legible")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Ejemplo:")
	fmt.Fprintln(os.Stderr, "  shinro-shell ping")
}

// usageUpdates imprime la ayuda del comando updates.
func usageUpdates() {
	fmt.Fprintln(os.Stderr, "uso: shinro-shell updates [check|update] [--json]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Descripción:")
	fmt.Fprintln(os.Stderr, "  Muestra el estado de actualizaciones del backend. Sin argumentos")
	fmt.Fprintln(os.Stderr, "  devuelve el último resultado en RAM; con 'check' fuerza una")
	fmt.Fprintln(os.Stderr, "  comprobación y con 'update' lanza la actualización unificada.")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "  El resumen no lista los paquetes (la UI los muestra); con --json")
	fmt.Fprintln(os.Stderr, "  se imprime el mensaje completo del protocolo.")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Opciones:")
	fmt.Fprintln(os.Stderr, "  check     comprueba ahora (puede tardar: descarga bases de datos)")
	fmt.Fprintln(os.Stderr, "  update    actualiza con los backends activos")
	fmt.Fprintln(os.Stderr, "  --json    muestra el JSON en crudo, incluidos los paquetes")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Ejemplos:")
	fmt.Fprintln(os.Stderr, "  shinro-shell updates")
	fmt.Fprintln(os.Stderr, "  shinro-shell updates check")
	fmt.Fprintln(os.Stderr, "  shinro-shell updates --json")
}

// usageFiles imprime la ayuda del comando files/search.
func usageFiles() {
	fmt.Fprintln(os.Stderr, "uso: shinro-shell files <texto> [--limit N]")
	fmt.Fprintln(os.Stderr, "       shinro-shell search <texto> [--limit N]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Descripción:")
	fmt.Fprintln(os.Stderr, "  Busca archivos en $HOME cuyo nombre contenga el texto dado.")
	fmt.Fprintln(os.Stderr, "  La búsqueda es difusa (substring, sin distinción de mayúsculas)")
	fmt.Fprintln(os.Stderr, "  y excluye directorios de caché, dependencias y control de versiones.")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Argumentos:")
	fmt.Fprintln(os.Stderr, "  texto    consulta de búsqueda (substring del nombre de archivo)")
	fmt.Fprintln(os.Stderr, "  --limit  número máximo de resultados (por defecto: 20)")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Ejemplos:")
	fmt.Fprintln(os.Stderr, "  shinro-shell files bashrc")
	fmt.Fprintln(os.Stderr, "  shinro-shell files README --limit 10")
	fmt.Fprintln(os.Stderr, "  shinro-shell search documento --limit 50")
}

// usageClipboard imprime la ayuda del comando clipboard.
func usageClipboard() {
	fmt.Fprintln(os.Stderr, "uso: shinro-shell clipboard <acción> [argumentos]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Descripción:")
	fmt.Fprintln(os.Stderr, "  Gestiona el historial del portapapeles a través del backend.")
	fmt.Fprintln(os.Stderr, "  Requiere que shinro-backend esté en ejecución.")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Acciones disponibles:")
	fmt.Fprintln(os.Stderr, "  list                         lista el historial del portapapeles")
	fmt.Fprintln(os.Stderr, "  delete <id>                  elimina una entrada del historial por id")
	fmt.Fprintln(os.Stderr, "  clear                        vacía el historial (conserva starred)")
	fmt.Fprintln(os.Stderr, "  star <id> <true|false>       marca o desmarca una entrada como favorita")
	fmt.Fprintln(os.Stderr, "  stats                        muestra estadísticas del historial")
	fmt.Fprintln(os.Stderr, "  get-text <id>                devuelve el contenido completo de una entrada")
	fmt.Fprintln(os.Stderr, "  recopy <id>                  vuelve a copiar una entrada al portapapeles")
	fmt.Fprintln(os.Stderr, "  watch [true|false]           activa o desactiva la vigilancia de cambios externos")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Ejemplos:")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard list")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard delete 42")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard star 42 true")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard stats")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard get-text 42")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard recopy 42")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard watch true")
}

// fatal imprime un error y sale con código 1.
func fatal(err error) {
	fmt.Fprintln(os.Stderr, "shinro-shell:", err)
	os.Exit(1)
}

// runStatus ejecuta el comando status.
func runStatus() error {
	raw, err := callModule("system", nil)
	if err != nil {
		return err
	}
	printJSON(raw)
	return nil
}

// updatesReport es el mensaje `update` del módulo updates.
type updatesReport struct {
	Type   string `json:"type"`
	Module string `json:"module"`
	Data   struct {
		Count    int `json:"count"`
		Packages []struct {
			Name    string `json:"name"`
			Old     string `json:"old"`
			New     string `json:"new"`
			Backend string `json:"backend"`
		} `json:"packages"`
		Checking        bool     `json:"checking"`
		CheckedAt       int64    `json:"checked_at"`
		Updating        bool     `json:"updating"`
		UpdatingBackend string   `json:"updating_backend"`
		LastUpdateAt    int64    `json:"last_update_at"`
		CanUpdate       bool     `json:"can_update"`
		Backends        []string `json:"backends"`
		UpdateScript    string   `json:"update_script"`
		Errors          []struct {
			Backend string `json:"backend"`
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"errors"`
	} `json:"data"`
}

// sendAndWait envía una línea al backend y espera a que done() acepte una
// respuesta. Se usa para las operaciones lentas de updates: check y update
// pueden tardar minutos y no caben en el deadline corto de sendCommand.
func sendAndWait(line string, timeout time.Duration, done func(map[string]any) bool) (string, error) {
	connection, err := net.DialTimeout("unix", sockPath(), 3*time.Second)
	if err != nil {
		return "", fmt.Errorf("daemon no alcanzable en %s (¿está shinro-backend ejecutándose?)", sockPath())
	}
	defer connection.Close()

	_ = connection.SetDeadline(time.Now().Add(timeout))
	if _, err := fmt.Fprintln(connection, line); err != nil {
		return "", err
	}

	reader := bufio.NewReader(connection)
	for {
		resp, err := reader.ReadString('\n')
		if err != nil {
			return "", fmt.Errorf("sin respuesta del daemon: %v", err)
		}
		resp = strings.TrimSpace(resp)
		if resp == "" {
			continue
		}

		var msg map[string]any
		if err := json.Unmarshal([]byte(resp), &msg); err != nil {
			return resp, nil
		}
		if msg["type"] == "error" {
			return "", fmt.Errorf("%v", msg["message"])
		}
		if msg["type"] == "update" && msg["module"] == "updates" {
			if done == nil || done(msg) {
				return resp, nil
			}
		}
	}
}

// runUpdates ejecuta el comando updates.
func runUpdates(args []string) error {
	asJSON := false
	action := "get"
	yes := false

	for _, arg := range args {
		switch arg {
		case "--json":
			asJSON = true
		case "--yes", "-y":
			yes = true
		case "check":
			action = "check"
		case "update":
			action = "update"
		case "-h", "--help", "help":
			usageUpdates()
			os.Exit(0)
		default:
			return fmt.Errorf("opción desconocida: %s", arg)
		}
	}

	if action == "update" {
		return runUpdatesUpdate(asJSON, yes)
	}

	payload := map[string]any{"type": "get", "module": "updates"}
	if action != "get" {
		payload["action"] = action
	}
	b, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	timeout := 15 * time.Minute
	if action == "update" {
		timeout = 60 * time.Minute
	}

	done := func(msg map[string]any) bool {
		data, ok := msg["data"].(map[string]any)
		if !ok {
			return true
		}
		checking, _ := data["checking"].(bool)
		updating, _ := data["updating"].(bool)
		switch action {
		case "check":
			return !checking
		case "update":
			return !checking && !updating
		default:
			return true
		}
	}

	raw, err := sendAndWait(string(b), timeout, done)
	if err != nil {
		return err
	}

	if asJSON {
		printJSON(raw)
		return nil
	}

	var report updatesReport
	if err := json.Unmarshal([]byte(raw), &report); err != nil {
		printJSON(raw)
		return nil
	}
	printUpdatesSummary(&report)
	return nil
}

// runUpdatesUpdate obtiene el script de actualización del backend, pide
// confirmación explícita al usuario y lo ejecuta en el terminal actual.
// No se delega la ejecución al daemon: así el usuario autoriza cada
// actualización de forma interactiva (polkit/sudo en el propio terminal).
func runUpdatesUpdate(asJSON, yes bool) error {
	raw, err := callModule("updates", nil)
	if err != nil {
		return err
	}
	var report updatesReport
	if err := json.Unmarshal([]byte(raw), &report); err != nil {
		printJSON(raw)
		return err
	}
	script := report.Data.UpdateScript
	if script == "" {
		return fmt.Errorf("el backend no expone un script de actualización (can_update=%v)", report.Data.CanUpdate)
	}

	fmt.Println("Comandos a ejecutar:")
	fmt.Println("  " + script)
	fmt.Println()

	if !yes {
		// Confirmación explícita. Si no hay TTY, exigir --yes.
		fi, _ := os.Stdin.Stat()
		if (fi.Mode() & os.ModeCharDevice) == 0 {
			return fmt.Errorf("sin terminal interactivo: use --yes para confirmar")
		}
		fmt.Print("¿Ejecutar la actualización? [y/N] ")
		reader := bufio.NewReader(os.Stdin)
		answer, _ := reader.ReadString('\n')
		answer = strings.TrimSpace(strings.ToLower(answer))
		if answer != "y" && answer != "s" && answer != "si" && answer != "sí" && answer != "yes" {
			fmt.Println("cancelado")
			return nil
		}
	}

	if asJSON {
		// No ejecutar en modo JSON: solo mostrar el script.
		printJSON(raw)
		return nil
	}

	cmd := exec.Command("/bin/sh", "-c", script)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("la actualización terminó con error: %w", err)
	}

	// Refrescar el contador tras la actualización.
	_, _ = callModule("updates", map[string]any{"action": "check"})
	fmt.Println()
	fmt.Println("actualización finalizada")
	return nil
}

// printUpdatesSummary imprime un resumen legible sin listar los paquetes.
func printUpdatesSummary(r *updatesReport) {
	d := r.Data

	if d.CheckedAt == 0 {
		fmt.Println("última comprobación: nunca")
	} else {
		age := time.Since(time.Unix(d.CheckedAt, 0))
		fmt.Printf("última comprobación: hace %s (%s)\n",
			humanAge(age), time.Unix(d.CheckedAt, 0).Format("15:04:05"))
	}

	fmt.Printf("actualizaciones: %d\n", d.Count)
	if len(d.Backends) > 0 {
		fmt.Printf("backends: %s\n", strings.Join(d.Backends, ", "))
	}
	if d.Count == 0 {
		fmt.Println("sin actualizaciones pendientes")
	}
	if d.Updating {
		if d.UpdatingBackend != "" {
			fmt.Printf("actualizando: %s\n", d.UpdatingBackend)
		} else {
			fmt.Println("actualizando…")
		}
	}

	if len(d.Errors) > 0 {
		fmt.Println()
		fmt.Println("errores:")
		for _, e := range d.Errors {
			fmt.Printf("  - %s (código %d): %s\n", e.Backend, e.Code, e.Message)
		}
	}
}

// humanAge formatea una duración de forma breve.
func humanAge(d time.Duration) string {
	seconds := int64(d.Seconds())
	switch {
	case seconds < 60:
		return fmt.Sprintf("%d s", seconds)
	case seconds < 3600:
		return fmt.Sprintf("%d min", seconds/60)
	case seconds < 86400:
		return fmt.Sprintf("%d h", seconds/3600)
	default:
		return fmt.Sprintf("%d días", seconds/86400)
	}
}

// pingReport es el informe de salud que devuelve el módulo ping.
type pingReport struct {
	Type   string `json:"type"`
	Module string `json:"module"`
	Data   struct {
		OK              string   `json:"ok"`
		Status          string   `json:"status"`
		UptimeSeconds   float64  `json:"uptime_seconds"`
		Goroutines      int      `json:"goroutines"`
		GoroutinesDelta int      `json:"goroutines_delta_5m"`
		MemoryDelta     float64  `json:"memory_delta_5m"`
		MemoryMB        float64  `json:"memory_mb"`
		Clients         int      `json:"clients"`
		Connectivity    string   `json:"connectivity"`
		Problems        []string `json:"problems"`
		Suggestions     []string `json:"suggestions"`
		Modules         []struct {
			Name         string             `json:"name"`
			Status       string             `json:"status"`
			Subscribed   bool               `json:"subscribed"`
			Subscribers  int                `json:"subscribers"`
			Interval     int                `json:"interval"`
			Sends        int64              `json:"sends"`
			Errors       int64              `json:"errors"`
			LastSendMS   int64              `json:"last_send_ms_ago"`
			LastDuration float64            `json:"last_duration_ms"`
			AvgDuration  float64            `json:"avg_duration_ms"`
			LastError    string             `json:"last_error"`
			Timings      map[string]float64 `json:"timings"`
		} `json:"modules"`
	} `json:"data"`
}

// runPing ejecuta el comando ping: comprueba que el backend responde y
// muestra su estado de salud.
//
// Por defecto imprime un resumen legible (es más útil para diagnosticar que
// un JSON pelado); con --json sale el informe tal cual.
func runPing(args []string) error {
	asJSON := false
	for _, arg := range args {
		switch arg {
		case "--json":
			asJSON = true
		default:
			return fmt.Errorf("opción desconocida: %s", arg)
		}
	}

	raw, err := callModule("ping", nil)
	if err != nil {
		return err
	}

	if asJSON {
		printJSON(raw)
		return nil
	}

	var report pingReport
	if err := json.Unmarshal([]byte(raw), &report); err != nil {
		// Si el backend es antiguo y devuelve otro formato, al menos se
		// imprime lo que venga.
		printJSON(raw)
		return nil
	}
	printPingSummary(&report)
	return nil
}

// printPingSummary imprime el informe de salud en texto legible.
func printPingSummary(r *pingReport) {
	d := r.Data

	fmt.Printf("estado: %s   Conectividad: %s\n", d.Status, d.Connectivity)
	tendencia := "sin datos (el daemon lleva menos de 5 min en marcha)"
	if d.GoroutinesDelta != 0 || d.MemoryDelta != 0 {
		tendencia = fmt.Sprintf("%+d goroutines, %+.1f MB en los últimos 5 min", d.GoroutinesDelta, d.MemoryDelta)
	}
	fmt.Printf("uptime: %s   clientes: %d   goroutines: %d   memoria: %.1f MB\n",
		humanDuration(d.UptimeSeconds), d.Clients, d.Goroutines, d.MemoryMB)
	fmt.Printf("tendencia: %s\n", tendencia)

	if len(d.Modules) > 0 {
		fmt.Println()
		fmt.Println("Módulo      Estado   Suscr.  Envíos  Errores  Último envío  Duración media")
		for _, m := range d.Modules {
			ultimo := "-"
			if m.LastSendMS >= 0 {
				ultimo = humanDurationMS(m.LastSendMS)
			}
			media := "-"
			if m.AvgDuration > 0 {
				media = fmt.Sprintf("%.1f ms", m.AvgDuration)
			}
			fmt.Printf("%-11s %-8s %-7d %-7d %-8d %-13s %s\n",
				m.Name, m.Status, m.Subscribers, m.Sends, m.Errors, ultimo, media)
		}
	}

	// Desglose del tiempo de los módulos que lo saben (el clima).
	for _, m := range d.Modules {
		if len(m.Timings) == 0 {
			continue
		}
		partes := make([]string, 0, len(m.Timings))
		for _, clave := range []string{"geocode_ms", "forecast_ms", "aqi_ms", "alerts_ms", "total_ms"} {
			v, ok := m.Timings[clave]
			if !ok {
				continue
			}
			partes = append(partes, fmt.Sprintf("%s %.1f ms", strings.TrimSuffix(clave, "_ms"), v))
		}
		if len(partes) > 0 {
			fmt.Printf("desglose de %s: %s\n", m.Name, strings.Join(partes, ", "))
		}
	}

	if len(d.Problems) > 0 {
		fmt.Println()
		fmt.Println("Problemas:")
		for _, p := range d.Problems {
			fmt.Printf("  - %s\n", p)
		}
	}

	if len(d.Suggestions) > 0 {
		fmt.Println()
		fmt.Println("Cosas a mejorar:")
		for _, s := range d.Suggestions {
			fmt.Printf("  - %s\n", s)
		}
	}
}

// humanDuration formatea un número de segundos de forma legible.
func humanDuration(seconds float64) string {
	switch {
	case seconds < 60:
		return fmt.Sprintf("%.0f s", seconds)
	case seconds < 3600:
		return fmt.Sprintf("%.0f min", seconds/60)
	case seconds < 86400:
		return fmt.Sprintf("%.1f h", seconds/3600)
	default:
		return fmt.Sprintf("%.1f días", seconds/86400)
	}
}

// humanDurationMS formatea una duración en milisegundos de forma legible.
func humanDurationMS(ms int64) string {
	switch {
	case ms < 0:
		return "-"
	case ms < 1000:
		return fmt.Sprintf("%d ms", ms)
	case ms < 60*1000:
		return fmt.Sprintf("%.1f s", float64(ms)/1000)
	case ms < 3600*1000:
		return fmt.Sprintf("%d min", ms/(60*1000))
	default:
		return fmt.Sprintf("%.1f h", float64(ms)/(3600*1000))
	}
}

// runFiles ejecuta el comando files/search. Acepta --limit delante o detrás
// de la consulta; todo lo que no sea una opción forma parte de la búsqueda.
func runFiles(args []string) error {
	query := ""
	limit := 20

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--limit" || arg == "-n":
			if i+1 >= len(args) {
				return fmt.Errorf("falta el valor de %s", arg)
			}
			n, err := strconv.Atoi(args[i+1])
			if err != nil || n <= 0 {
				return fmt.Errorf("límite inválido: %q", args[i+1])
			}
			limit = n
			i++
		case strings.HasPrefix(arg, "--limit="):
			v := strings.TrimPrefix(arg, "--limit=")
			n, err := strconv.Atoi(v)
			if err != nil || n <= 0 {
				return fmt.Errorf("límite inválido: %q", v)
			}
			limit = n
		case strings.HasPrefix(arg, "-") && arg != "-":
			return fmt.Errorf("opción desconocida: %s", arg)
		default:
			if query == "" {
				query = arg
			} else {
				query += " " + arg
			}
		}
	}

	if query == "" {
		return fmt.Errorf("falta la consulta de búsqueda: shinro-shell files <texto>")
	}

	raw, err := callModule("files", map[string]any{
		"action": "search",
		"query":  query,
		"limit":  limit,
	})
	if err != nil {
		return err
	}
	printJSON(raw)
	return nil
}

// runClipboard ejecuta el comando clipboard.
func runClipboard(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("falta la acción: shinro-shell clipboard <acción> [argumentos]\nUsa 'shinro-shell clipboard --help' para ver las acciones disponibles")
	}

	action := args[0]
	rest := args[1:]

	switch action {
	case "-h", "--help", "help":
		usageClipboard()
		os.Exit(0)

	case "list":
		if len(rest) > 0 {
			return fmt.Errorf("acción 'list' no acepta argumentos: shinro-shell clipboard list")
		}
		raw, err := callModule("clipboard", map[string]any{"action": "list"})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "delete":
		if len(rest) == 0 {
			return fmt.Errorf("falta el id: shinro-shell clipboard delete <id>")
		}
		id, err := parseID(rest[0])
		if err != nil {
			return err
		}
		raw, err := callModule("clipboard", map[string]any{
			"action": "delete",
			"confirm": true,
			"id":     id,
		})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "clear":
		if len(rest) > 0 {
			return fmt.Errorf("acción 'clear' no acepta argumentos: shinro-shell clipboard clear")
		}
		raw, err := callModule("clipboard", map[string]any{"action": "clear",
			"confirm": true})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "star":
		if len(rest) < 2 {
			return fmt.Errorf("faltan argumentos: shinro-shell clipboard star <id> <true|false>")
		}
		id, err := parseID(rest[0])
		if err != nil {
			return err
		}
		starred := rest[1] == "true" || rest[1] == "1" || rest[1] == "sí"
		raw, err := callModule("clipboard", map[string]any{
			"action":  "star",
			"confirm": true,
			"id":      id,
			"starred": starred,
		})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "stats":
		if len(rest) > 0 {
			return fmt.Errorf("acción 'stats' no acepta argumentos: shinro-shell clipboard stats")
		}
		raw, err := callModule("clipboard", map[string]any{"action": "stats"})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "get-text":
		if len(rest) == 0 {
			return fmt.Errorf("falta el id: shinro-shell clipboard get-text <id>")
		}
		id, err := parseID(rest[0])
		if err != nil {
			return err
		}
		raw, err := callModule("clipboard", map[string]any{
			"action": "get-text",
			"id":     id,
		})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "recopy":
		if len(rest) == 0 {
			return fmt.Errorf("falta el id: shinro-shell clipboard recopy <id>")
		}
		id, err := parseID(rest[0])
		if err != nil {
			return err
		}
		raw, err := callModule("clipboard", map[string]any{
			"action": "recopy",
			"confirm": true,
			"id":     id,
		})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "watch":
		if len(rest) == 0 {
			return fmt.Errorf("falta el estado: shinro-shell clipboard watch <true|false>")
		}
		enable := rest[0] == "true" || rest[0] == "1" || rest[0] == "sí"
		raw, err := callModule("clipboard", map[string]any{
			"action": "watch",
			"confirm": true,
			"enable": enable,
		})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	default:
		return fmt.Errorf("acción desconocida: %s\nUsa 'shinro-shell clipboard --help' para ver las acciones disponibles", action)
	}
	return nil
}

// parseID convierte un string a uint64 validando el formato.
func parseID(s string) (uint64, error) {
	n, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("id inválido: %q", s)
	}
	return n, nil
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	command := os.Args[1]
	args := os.Args[2:]

	// Ayuda general
	switch command {
	case "-h", "--help", "help":
		usage()
		os.Exit(0)
	}

	// Ayuda específica por comando
	switch command {
	case "status":
		if len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
			usageStatus()
			os.Exit(0)
		}
		if err := runStatus(); err != nil {
			fatal(err)
		}
		return

	case "ping":
		if len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
			usagePing()
			os.Exit(0)
		}
		if err := runPing(args); err != nil {
			fatal(err)
		}
		return

	case "updates", "update":
		if len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
			usageUpdates()
			os.Exit(0)
		}
		if err := runUpdates(args); err != nil {
			fatal(err)
		}
		return

	case "files", "search":
		if len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
			usageFiles()
			os.Exit(0)
		}
		if err := runFiles(args); err != nil {
			fatal(err)
		}
		return

	case "clipboard", "clip":
		if len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
			usageClipboard()
			os.Exit(0)
		}
		if err := runClipboard(args); err != nil {
			fatal(err)
		}
		return

	default:
		fmt.Fprintf(os.Stderr, "comando desconocido: %s\n\n", command)
		usage()
		os.Exit(2)
	}
	return
}
