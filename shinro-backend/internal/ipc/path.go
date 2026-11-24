// Package ipc centraliza la resolución del socket Unix de shinro y las
// comprobaciones de seguridad sobre su directorio.
//
// Antes, el backend, el CLI y (parcialmente) la shell replicaban esta lógica
// y, si no había directorio runtime, caían a /tmp. Ese fallback permitía a
// otro usuario local precrear /tmp/shinro-<uid>, colocar un socket falso o
// impedir el arranque. Ahora, sin un directorio runtime de confianza, el
// arranque falla en vez de degradar la seguridad.
package ipc

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"syscall"
)

const socketName = "shinro"

// ErrNoRuntimeDir se devuelve cuando no hay un directorio runtime de confianza
// donde colocar el socket.
var ErrNoRuntimeDir = errors.New("no hay un directorio runtime seguro para el socket")

// DefaultSocketPath resuelve la ruta del socket con el mismo orden que usan
// el backend, el CLI y la shell:
//
//	$SHINRO_SOCKET_PATH → $XDG_RUNTIME_DIR/shinro → /run/user/$UID/shinro
//
// El fallback a os.TempDir() se ha eliminado a propósito: /tmp es compartido y
// permite secuestrar el socket de otro usuario.
func DefaultSocketPath() (string, error) {
	if p := os.Getenv("SHINRO_SOCKET_PATH"); p != "" {
		if !filepath.IsAbs(p) {
			return "", fmt.Errorf("SHINRO_SOCKET_PATH debe ser una ruta absoluta: %q", p)
		}
		return p, nil
	}

	if rt := os.Getenv("XDG_RUNTIME_DIR"); rt != "" {
		if err := CheckPrivateDir(rt); err != nil {
			return "", fmt.Errorf("XDG_RUNTIME_DIR no es seguro: %w", err)
		}
		return filepath.Join(rt, socketName), nil
	}

	runUser := filepath.Join("/run/user", strconv.Itoa(os.Getuid()))
	if fi, err := os.Lstat(runUser); err == nil && fi.IsDir() {
		if err := CheckPrivateDir(runUser); err == nil {
			return filepath.Join(runUser, socketName), nil
		}
	}

	return "", fmt.Errorf("%w: defina XDG_RUNTIME_DIR o SHINRO_SOCKET_PATH", ErrNoRuntimeDir)
}

// EnsurePrivateDir crea dir con permisos 0700 si no existe y comprueba que sea
// un directorio real, propiedad del usuario actual y no escribible por grupo
// ni por otros. Es la comprobación que evita que otro usuario coloque un
// socket o un lockfile en nuestro nombre.
func EnsurePrivateDir(dir string) error {
	if dir == "" || dir == "." {
		return errors.New("directorio vacío")
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	return CheckPrivateDir(dir)
}

// CheckPrivateDir valida un directorio ya existente.
func CheckPrivateDir(dir string) error {
	fi, err := os.Lstat(dir)
	if err != nil {
		return err
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("%s es un enlace simbólico", dir)
	}
	if !fi.IsDir() {
		return fmt.Errorf("%s no es un directorio", dir)
	}
	st, ok := fi.Sys().(*syscall.Stat_t)
	if !ok {
		return fmt.Errorf("no se pueden leer los metadatos de %s", dir)
	}
	if int(st.Uid) != os.Getuid() {
		return fmt.Errorf("%s pertenece a otro usuario (uid %d)", dir, st.Uid)
	}
	if fi.Mode().Perm()&0o022 != 0 {
		return fmt.Errorf("%s es escribible por grupo u otros (modo %04o)", dir, fi.Mode().Perm())
	}
	return nil
}
