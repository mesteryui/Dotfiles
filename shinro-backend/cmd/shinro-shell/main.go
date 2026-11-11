package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const defaultSockName = "shinro"

// sockPath devuelve la ruta del socket Unix del backend.
func sockPath() string {
	if p := os.Getenv("SHINRO_SOCKET_PATH"); p != "" {
		return p
	}
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		dir = "/tmp"
	}
	return filepath.Join(dir, defaultSockName)
}

// sendCommand envía una línea al backend y devuelve la respuesta.
func sendCommand(line string) (string, error) {
	connection, err := net.DialTimeout("unix", sockPath(), 3*time.Second)
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
	for key, value := range extra {
		payload[key] = value
	}
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
	fmt.Fprintln(os.Stderr, "  status                 resumen del sistema (CPU, RAM, disco, red)")
	fmt.Fprintln(os.Stderr, "  ping                   comprueba que el backend responde")
	fmt.Fprintln(os.Stderr, "  files <texto>          búsqueda difusa de archivos en $HOME")
	fmt.Fprintln(os.Stderr, "  clipboard <acción>     gestiona el historial del portapapeles")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Ejemplos:")
	fmt.Fprintln(os.Stderr, "  shinro-shell status")
	fmt.Fprintln(os.Stderr, "  shinro-shell files documento")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard list")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard copy-text \"hola mundo\"")
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
	fmt.Fprintln(os.Stderr, "uso: shinro-shell ping")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Descripción:")
	fmt.Fprintln(os.Stderr, "  Envía una petición al backend y espera una respuesta para")
	fmt.Fprintln(os.Stderr, "  verificar que el daemon está en ejecución y responde.")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Ejemplo:")
	fmt.Fprintln(os.Stderr, "  shinro-shell ping")
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
	fmt.Fprintln(os.Stderr, "  copy-text <texto>            copia texto al portapapeles y al historial")
	fmt.Fprintln(os.Stderr, "  copy-image <ruta>            copia una imagen al portapapeles y al historial")
	fmt.Fprintln(os.Stderr, "  paste                        pega el contenido actual como texto")
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
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard copy-text \"texto a copiar\"")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard copy-image /ruta/a/imagen.png")
	fmt.Fprintln(os.Stderr, "  shinro-shell clipboard paste")
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

// runPing ejecuta el comando ping.
func runPing() error {
	raw, err := callModule("ping", nil)
	if err != nil {
		return err
	}
	printJSON(raw)
	return nil
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

	case "copy-text":
		if len(rest) == 0 {
			return fmt.Errorf("falta el texto: shinro-shell clipboard copy-text <texto>")
		}
		text := strings.Join(rest, " ")
		raw, err := callModule("clipboard", map[string]any{
			"action": "copy-text",
			"text":   text,
		})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "copy-image":
		if len(rest) == 0 {
			return fmt.Errorf("falta la ruta: shinro-shell clipboard copy-image <ruta>")
		}
		raw, err := callModule("clipboard", map[string]any{
			"action": "copy-image",
			"path":   rest[0],
		})
		if err != nil {
			return err
		}
		printJSON(raw)
		return nil

	case "paste":
		if len(rest) > 0 {
			return fmt.Errorf("acción 'paste' no acepta argumentos: shinro-shell clipboard paste")
		}
		raw, err := callModule("clipboard", map[string]any{"action": "paste"})
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
		raw, err := callModule("clipboard", map[string]any{"action": "clear"})
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
	case "status", "-h", "--help", "help":
		if command == "status" && len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
			usageStatus()
			os.Exit(0)
		}
		if command == "status" {
			if err := runStatus(); err != nil {
				fatal(err)
			}
			return
		}

	case "ping":
		if len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
			usagePing()
			os.Exit(0)
		}
		if err := runPing(); err != nil {
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
