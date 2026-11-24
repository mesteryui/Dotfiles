package socket

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"math/rand/v2"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"shinro-backend/internal/logger"
)

// TestRandomPayloadsRespondeJSON envía 500 cuerpos JSON aleatorios al socket
// Unix y comprueba únicamente que el servidor sigue respondiendo bien y que
// cualquier respuesta recibida es JSON válido.
func TestRandomPayloadsRespondeJSON(t *testing.T) {
	logger.Init()

	tmpDir := t.TempDir()
	socketPath := tmpDir + "/shinro"
	t.Setenv("SHINRO_SOCKET_PATH", socketPath)

	registry := NewRegistry()
	registry.Register(&pingModule{})
	srv := NewServer(registry, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() { errCh <- srv.Start(ctx) }()

	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(socketPath); err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	defer conn.Close()

	rng := rand.New(rand.NewPCG(42, 7))

	for i := 0; i < 500; i++ {
		body := randomJSONBody(rng, i)
		if _, err := conn.Write([]byte(body + "\n")); err != nil {
			t.Fatalf("error enviando cuerpo aleatorio %d: %v", i, err)
		}

		// Drenar respuestas disponibles sin bloquear. No todo cuerpo genera
		// respuesta (p. ej. JSON que no es objeto o sin tipo conocido), pero
		// si llega alguna, debe ser JSON válido.
		drainAvailableResponses(t, conn)
	}

	// Comprobar que el servidor sigue vivo y responde bien tras los 500 cuerpos.
	ping := `{"type":"get","module":"ping"}`
	if _, err := conn.Write([]byte(ping + "\n")); err != nil {
		t.Fatalf("error enviando ping final: %v", err)
	}

	resp, err := readJSONResponse(conn, 5*time.Second)
	if err != nil {
		t.Fatalf("el servidor no respondió bien al ping final: %v", err)
	}
	if !json.Valid([]byte(resp)) {
		t.Fatalf("la respuesta final no es JSON válido: %q", resp)
	}

	cancel()
	select {
	case err := <-errCh:
		if err != nil && err != context.Canceled {
			t.Fatalf("error al detener servidor: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timeout esperando a que se detuviera el servidor")
	}
}

func drainAvailableResponses(t *testing.T, conn net.Conn) {
	t.Helper()
	for {
		_ = conn.SetReadDeadline(time.Now().Add(10 * time.Millisecond))
		line, err := readLine(conn, 10*time.Millisecond)
		if err != nil {
			if ne, ok := err.(net.Error); ok && ne.Timeout() {
				return
			}
			if strings.TrimSpace(line) == "" {
				return
			}
			// Si llegó algo parcial con error, igual debe ser JSON válido si
			// parece una línea completa; si no, el servidor cerró.
			trimmed := strings.TrimSpace(line)
			if trimmed != "" && !json.Valid([]byte(trimmed)) {
				t.Fatalf("respuesta no JSON recibida: %q (err=%v)", trimmed, err)
			}
			return
		}
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		if !json.Valid([]byte(trimmed)) {
			t.Fatalf("respuesta no JSON recibida: %q", trimmed)
		}
	}
}

func readJSONResponse(conn net.Conn, timeout time.Duration) (string, error) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		line, err := readLine(conn, remaining)
		trimmed := strings.TrimSpace(line)
		if trimmed != "" {
			if !json.Valid([]byte(trimmed)) {
				return trimmed, fmt.Errorf("respuesta no JSON: %q", trimmed)
			}
			return trimmed, nil
		}
		if err != nil {
			if ne, ok := err.(net.Error); ok && ne.Timeout() {
				continue
			}
			return "", err
		}
	}
	return "", fmt.Errorf("timeout esperando respuesta JSON")
}

func randomJSONBody(rng *rand.Rand, i int) string {
	// Mezcla de formas: objetos de protocolo raros, valores JSON crudos,
	// objetos anidados, números enormes, tipos mezclados y basura estructurada.
	switch rng.IntN(12) {
	case 0:
		return randomNestedObject(rng, 0)
	case 1:
		return randomRawJSON(rng)
	case 2:
		return randomHugeNumberJSON(rng)
	case 3:
		return randomMixedArray(rng, 0)
	case 4:
		return randomProtocolish(rng, i)
	case 5:
		return randomWeirdObject(rng)
	case 6:
		return randomStringJSON(rng)
	case 7:
		return randomBoolNullJSON(rng)
	case 8:
		return randomDeeplyNested(rng)
	case 9:
		return randomLargeObject(rng)
	case 10:
		return randomTypedGarbage(rng, i)
	default:
		return randomNestedObject(rng, 0)
	}
}

func randomNestedObject(rng *rand.Rand, depth int) string {
	n := rng.IntN(6) + 1
	fields := make([]string, 0, n)
	for j := 0; j < n; j++ {
		k := randomKey(rng, j)
		v := randomValue(rng, depth+1)
		fields = append(fields, fmt.Sprintf("%q:%s", k, v))
	}
	return "{" + strings.Join(fields, ",") + "}"
}

func randomDeeplyNested(rng *rand.Rand) string {
	// Objeto anidado con profundidad moderada para no explotar el tamaño.
	v := randomScalar(rng)
	depth := rng.IntN(20) + 5
	for d := 0; d < depth; d++ {
		k := fmt.Sprintf("n%d", d)
		v = fmt.Sprintf("{%q:%s}", k, v)
	}
	return v
}

func randomLargeObject(rng *rand.Rand) string {
	n := rng.IntN(40) + 20
	fields := make([]string, 0, n)
	for j := 0; j < n; j++ {
		k := fmt.Sprintf("k_%d_%d", j, rng.IntN(100000))
		fields = append(fields, fmt.Sprintf("%q:%s", k, randomValue(rng, 2)))
	}
	return "{" + strings.Join(fields, ",") + "}"
}

func randomMixedArray(rng *rand.Rand, depth int) string {
	n := rng.IntN(8) + 1
	items := make([]string, 0, n)
	for j := 0; j < n; j++ {
		items = append(items, randomValue(rng, depth+1))
	}
	return "[" + strings.Join(items, ",") + "]"
}

func randomProtocolish(rng *rand.Rand, i int) string {
	types := []string{"hello", "get", "ping", "update", "subscribe", "unknown", "", "HELLO", "get\x00", "type"}
	modules := []string{"ping", "system", "weather", "clipboard", "files", "updates", "nope", "", "a/b", strings.Repeat("m", rng.IntN(200))}
	t := types[rng.IntN(len(types))]
	m := modules[rng.IntN(len(modules))]
	extra := randomNestedObject(rng, 1)
	return fmt.Sprintf(`{"type":%q,"module":%q,"seq":%d,"extra":%s,"intervals":{"system":%d,"weather":%d},"location":{"mode":%q,"city":%q,"lat":%s,"lon":%s}}`,
		t, m, i, extra,
		rng.IntN(5)-1, rng.IntN(5)-1,
		randomMode(rng), randomCity(rng),
		randomNumber(rng), randomNumber(rng),
	)
}

func randomWeirdObject(rng *rand.Rand) string {
	return fmt.Sprintf(`{"":%s,%q:%s,"nested":{"arr":[%s,%s],"obj":%s},"big":%s,"float":%s,"mixed":[%s,%q,false,null]}`,
		randomValue(rng, 1),
		"clave\ncon\tcosas\"raras", randomValue(rng, 1),
		randomNestedObject(rng, 1), randomMixedArray(rng, 1), randomNestedObject(rng, 2),
		randomHugeInteger(rng), randomHugeFloat(rng),
		randomHugeInteger(rng), strings.Repeat("z", rng.IntN(50)),
	)
}

func randomTypedGarbage(rng *rand.Rand, i int) string {
	// Objetos con tipos mezclados en campos donde el servidor espera algo concreto.
	return fmt.Sprintf(`{"type":%s,"module":%s,"location":%s,"intervals":%s,"action":%s,"id":%s,"n":%d}`,
		randomValue(rng, 1),
		randomValue(rng, 1),
		randomValue(rng, 1),
		randomValue(rng, 1),
		randomValue(rng, 1),
		randomValue(rng, 1),
		i,
	)
}

func randomValue(rng *rand.Rand, depth int) string {
	if depth > 4 {
		return randomScalar(rng)
	}
	switch rng.IntN(10) {
	case 0, 1, 2, 3:
		return randomScalar(rng)
	case 4, 5:
		return randomNestedObject(rng, depth)
	case 6:
		return randomMixedArray(rng, depth)
	case 7:
		return randomHugeNumberJSON(rng)
	case 8:
		return randomDeeplyNestedValue(rng, depth)
	default:
		return randomScalar(rng)
	}
}

func randomDeeplyNestedValue(rng *rand.Rand, depth int) string {
	v := randomScalar(rng)
	steps := rng.IntN(4) + 1
	for s := 0; s < steps && depth+s < 6; s++ {
		if rng.IntN(2) == 0 {
			v = fmt.Sprintf("[%s,%s]", v, randomScalar(rng))
		} else {
			v = fmt.Sprintf("{%q:%s}", fmt.Sprintf("d%d", s), v)
		}
	}
	return v
}

func randomScalar(rng *rand.Rand) string {
	switch rng.IntN(7) {
	case 0:
		return fmt.Sprintf("%q", randomString(rng))
	case 1:
		return randomNumber(rng)
	case 2:
		return randomHugeInteger(rng)
	case 3:
		return randomHugeFloat(rng)
	case 4:
		if rng.IntN(2) == 0 {
			return "true"
		}
		return "false"
	case 5:
		return "null"
	default:
		return fmt.Sprintf("%q", randomString(rng))
	}
}

func randomRawJSON(rng *rand.Rand) string {
	switch rng.IntN(7) {
	case 0:
		return fmt.Sprintf("%q", randomString(rng))
	case 1:
		return randomNumber(rng)
	case 2:
		return randomHugeInteger(rng)
	case 3:
		if rng.IntN(2) == 0 {
			return "true"
		}
		return "false"
	case 4:
		return "null"
	case 5:
		return randomMixedArray(rng, 0)
	default:
		return fmt.Sprintf("%q", "raw-"+randomString(rng))
	}
}

func randomStringJSON(rng *rand.Rand) string {
	return fmt.Sprintf("%q", randomString(rng))
}

func randomBoolNullJSON(rng *rand.Rand) string {
	v := []string{"true", "false", "null"}
	return v[rng.IntN(len(v))]
}

func randomHugeNumberJSON(rng *rand.Rand) string {
	if rng.IntN(2) == 0 {
		return randomHugeInteger(rng)
	}
	return randomHugeFloat(rng)
}

func randomHugeInteger(rng *rand.Rand) string {
	candidates := []string{
		"9223372036854775807",
		"-9223372036854775808",
		"18446744073709551615",
		"-18446744073709551616",
		"9999999999999999999999999999999999999999",
		"-9999999999999999999999999999999999999999",
		fmt.Sprintf("%d%d%d%d", rng.Uint64(), rng.Uint64(), rng.Uint64(), rng.Uint64()),
		"0",
		"-0",
		"1e308",
	}
	return candidates[rng.IntN(len(candidates))]
}

func randomHugeFloat(rng *rand.Rand) string {
	candidates := []string{
		"1.7976931348623157e+308",
		"-1.7976931348623157e+308",
		"5e-324",
		"-5e-324",
		"1e309",
		"-1e309",
		"3.14159265358979323846264338327950288419716939937510",
		fmt.Sprintf("%d.%d", rng.Int64(), rng.Uint64()),
		"0.0000000000000000000000000000000001",
	}
	// A veces NaN/Infinity no son JSON válido; evitarlos para que el cuerpo
	// enviado sea JSON crudo válido, como pide el usuario.
	_ = math.MaxFloat64
	return candidates[rng.IntN(len(candidates))]
}

func randomNumber(rng *rand.Rand) string {
	switch rng.IntN(5) {
	case 0:
		return fmt.Sprintf("%d", rng.IntN(2000000)-1000000)
	case 1:
		return fmt.Sprintf("%f", rng.Float64()*100000-50000)
	case 2:
		return fmt.Sprintf("%de%d", rng.IntN(1000), rng.IntN(100))
	case 3:
		return fmt.Sprintf("-%d", rng.Uint64())
	default:
		return "0"
	}
}

func randomString(rng *rand.Rand) string {
	chunks := []string{
		"", "hola", "Vigo", "null", "true", "false", "{}", "[]",
		"línea\nnueva", "tab\t", `"quoted"`, `barra\`, "emoji🚀", "acentó",
		strings.Repeat("a", rng.IntN(200)),
		fmt.Sprintf("id-%d", rng.IntN(100000)),
	}
	return chunks[rng.IntN(len(chunks))]
}

func randomKey(rng *rand.Rand, j int) string {
	keys := []string{"type", "module", "data", "location", "intervals", "action", "id", "nested", "value", "extra", ""}
	if rng.IntN(4) == 0 {
		return fmt.Sprintf("k_%d_%d", j, rng.IntN(1000))
	}
	return keys[rng.IntN(len(keys))]
}

func randomMode(rng *rand.Rand) string {
	modes := []string{"manual", "auto", "", "MANUAL", "unknown", "0", "null"}
	return modes[rng.IntN(len(modes))]
}

func randomCity(rng *rand.Rand) string {
	cities := []string{"Vigo", "Madrid", "", "A Coruña", strings.Repeat("x", rng.IntN(100)), "null", "0"}
	return cities[rng.IntN(len(cities))]
}
