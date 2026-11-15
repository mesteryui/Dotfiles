// Package safe centraliza la protección de goroutines del backend.
//
// El backend es un daemon de larga vida que hace de todo: clima, sistema,
// portapapeles, búsqueda de archivos y escucha de red. En Go, un panic sin
// recuperar en CUALQUIER goroutine tumba el proceso entero, y con él la
// shell. Un único panic al parsear una respuesta inesperada del proveedor de
// clima no puede permitirse que se lleve por delante el daemon.
//
// Por eso todo arranque de goroutine pasa por aquí:
//
//	safe.Go("clima", func() { ... })   // protegido: el panic se registra
//	safe.Do("clima", func() error { ... }) // protegido: el panic es un error
//
// El panic se registra con su stack (para poder diagnosticarlo) y el proceso
// sigue vivo: el fallo queda aislado al módulo que lo provocando.
package safe

import (
	"fmt"
	"runtime/debug"

	"shinro-backend/internal/logger"
)

// Go lanza fn en una goroutine nueva protegida contra panics.
// Si fn entra en panic, el panic se recupera y se registra con su stack;
// el proceso no se cae y el resto de goroutines siguen su curso.
//
// name identifica la goroutine en los logs (p. ej. "clima.forecast").
func Go(name string, fn func()) {
	go func() {
		defer Recover(name)
		fn()
	}()
}

// Recover captura un panic de la goroutine actual y lo registra. Se usa como
// `defer safe.Recover("nombre")` para proteger un bloque de código que no
// necesariamente vive en su propia goroutine.
//
// Esta función DEBE llamarse con defer: recover() solo funciona dentro de
// una función diferida.
func Recover(name string) {
	r := recover()
	if r == nil {
		return
	}
	logger.Error("panic recuperado",
		"goroutine", name,
		"panic", fmt.Sprint(r),
		"stack", string(debug.Stack()),
	)
}

// Do ejecuta fn recuperando cualquier panic.
//
// Devuelve el error de fn; si fn entra en panic, devuelve un error que
// describe el panic en lugar de propagarlo. Permite que un fallo puntual
// (por ejemplo, una respuesta malformada del proveedor de clima) se reporte
// como error al cliente sin derribar el daemon.
func Do(name string, fn func() error) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic en %s: %v", name, r)
			logger.Error("panic recuperado",
				"goroutine", name,
				"panic", fmt.Sprint(r),
				"stack", string(debug.Stack()),
			)
		}
	}()
	return fn()
}

// Guard ejecuta fn recuperando cualquier panic.
//
// Devuelve true si fn terminó sin panic y false si hubo un panic (que queda
// registrado con su stack). Se usa en bucles de fondo que deben sobrevivir a
// un fallo puntual y reintentar, en vez de morir y dejar el módulo sin
// vigilancia.
func Guard(name string, fn func()) (ok bool) {
	ok = true
	defer func() {
		if r := recover(); r != nil {
			ok = false
			logger.Error("panic recuperado",
				"goroutine", name,
				"panic", fmt.Sprint(r),
				"stack", string(debug.Stack()),
			)
		}
	}()
	fn()
	return ok
}

// DoValue es la versión de Do para funciones que devuelven un valor además
// del error. Si fn entra en panic, se devuelve el valor cero y un error.
//
//	aqi, err := safe.DoValue("clima.aqi", func() (int, error) { ... })
func DoValue[T any](name string, fn func() (T, error)) (value T, err error) {
	defer func() {
		if r := recover(); r != nil {
			var zero T
			value = zero
			err = fmt.Errorf("panic en %s: %v", name, r)
			logger.Error("panic recuperado",
				"goroutine", name,
				"panic", fmt.Sprint(r),
				"stack", string(debug.Stack()),
			)
		}
	}()
	return fn()
}
