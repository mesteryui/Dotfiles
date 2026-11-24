package updates

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"time"
)

// Runner ejecuta los comandos de los backends con las garantías que necesita
// un daemon de larga vida:
//
//   - nunca pasa por una shell (argv, no string);
//   - nice -n 10 para no competir con la sesión gráfica;
//   - timeout;
//   - límite de salida (un comando roto no puede llenar la RAM);
//   - LC_ALL=C para que los parsers no dependan del idioma.
type Runner struct {
	Timeout   time.Duration
	MaxOutput int
	Nice      bool
	LookPath  LookPath
}

// NewRunner crea el ejecutor real.
func NewRunner() *Runner {
	return &Runner{
		Timeout:   15 * time.Minute,
		MaxOutput: 4 << 20, // 4 MiB
		Nice:      true,
		LookPath:  exec.LookPath,
	}
}

// Run ejecuta argv y devuelve stdout, stderr y el código de salida.
//
// Un código distinto de cero NO es un error de Run: cada backend decide qué
// códigos significan "hay actualizaciones" (dnf usa 100, checkupdates 2...).
// Run solo devuelve error si el proceso no se pudo lanzar, si se agotó el
// tiempo o si la salida superó el límite.
func (r *Runner) Run(ctx context.Context, argv []string) (Output, error) {
	if len(argv) == 0 || argv[0] == "" {
		return Output{Exit: -1}, fmt.Errorf("argv vacío")
	}

	// El timeout del runner solo se aplica si el llamador no puso uno: así
	// las actualizaciones (que pueden durar mucho más que una comprobación)
	// usan su propio plazo.
	if r.Timeout > 0 {
		if _, ok := ctx.Deadline(); !ok {
			var cancel context.CancelFunc
			ctx, cancel = context.WithTimeout(ctx, r.Timeout)
			defer cancel()
		}
	}

	cmdArgv := append([]string(nil), argv...)
	if r.Nice && r.LookPath != nil {
		if _, err := r.LookPath("nice"); err == nil {
			cmdArgv = append([]string{"nice", "-n", "10"}, cmdArgv...)
		}
	}

	cmd := exec.CommandContext(ctx, cmdArgv[0], cmdArgv[1:]...)
	cmd.Env = append(os.Environ(),
		"LC_ALL=C",
		"LANG=C",
		"LANGUAGE=C",
		"NO_COLOR=1",
		"TERM=dumb",
	)

	outBuf := &limitedBuffer{limit: r.MaxOutput}
	errBuf := &limitedBuffer{limit: r.MaxOutput / 8}
	cmd.Stdout = outBuf
	cmd.Stderr = errBuf

	err := cmd.Run()

	exit := 0
	if err != nil {
		if exitErr, ok := errors.AsType[*exec.ExitError](err); ok {
			exit = exitErr.ExitCode()
		} else {
			if ctx.Err() != nil {
				return Output{Stdout: outBuf.Bytes(), Stderr: errBuf.Bytes(), Exit: -1}, fmt.Errorf("timeout ejecutando %s", argv[0])
			}
			return Output{Stdout: outBuf.Bytes(), Stderr: errBuf.Bytes(), Exit: -1}, fmt.Errorf("no se pudo ejecutar %s: %w", argv[0], err)
		}
	}

	if outBuf.truncated || errBuf.truncated {
		return Output{Stdout: outBuf.Bytes(), Stderr: errBuf.Bytes(), Exit: exit}, fmt.Errorf("salida de %s demasiado grande", argv[0])
	}

	return Output{
		Stdout: outBuf.Bytes(),
		Stderr: errBuf.Bytes(),
		Exit:   exit,
	}, nil
}

// limitedBuffer guarda hasta limit bytes y descarta el resto, marcando que se
// truncó. El proceso sigue escribiendo sin bloquearse.
type limitedBuffer struct {
	buf       bytes.Buffer
	limit     int
	truncated bool
}

func (b *limitedBuffer) Write(p []byte) (int, error) {
	if b.limit <= 0 {
		return b.buf.Write(p)
	}
	remaining := b.limit - b.buf.Len()
	if remaining <= 0 {
		b.truncated = true
		return len(p), nil
	}
	if len(p) <= remaining {
		_, _ = b.buf.Write(p)
		return len(p), nil
	}
	_, _ = b.buf.Write(p[:remaining])
	b.truncated = true
	return len(p), nil
}

func (b *limitedBuffer) Bytes() []byte {
	return b.buf.Bytes()
}

var _ Executor = (*Runner)(nil)
