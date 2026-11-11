// Package files busca archivos en el sistema de archivos usando solo la
// biblioteca estándar de Go (filepath.WalkDir), sin depender de fd ni find.
//
// La búsqueda es PARALELA y CONCURRENTE: los directorios de nivel superior
// se recorren en goroutines independientes, con un semáforo para no saturar
// el disco. Los resultados se agrupan y se devuelven ordenados.
//
// La búsqueda es difusa: el nombre del archivo debe contener la consulta
// (substring, sin distinción de mayúsculas).
//
// EXCLUSIONES (nunca se buscan):
//   - Cualquier directorio u archivo cuyo nombre empiece con "." (ocultos):
//     .git, .cache, .config, .local, .wine, .bashrc, .profile, etc.
//   - node_modules, __pycache__
//   - Enlaces simbólicos (evita duplicados y rutas rotas)
//
// Para búsquedas progresivas (tecla a tecla), se mantiene un caché de las
// últimas consultas y, si la nueva consulta empieza por una previa, se
// filtran los resultados ya obtenidos en lugar de reescanear el disco.
package files

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// Result representa un archivo encontrado. Mime y Kind los calcula el
// backend (ver mime.go): Quickshell usa Kind para decidir el preview.
type Result struct {
	Path  string `json:"path"`
	Name  string `json:"name"`
	Size  int64  `json:"size"`
	IsDir bool   `json:"is_dir"`
	Mime  string `json:"mime,omitempty"`
	Kind  string `json:"kind,omitempty"`
}

// Provider realiza búsquedas de archivos de forma concurrente.
type Provider struct {
	cache   map[string]cachedSearch // caché de consultas recientes
	cacheMu sync.RWMutex            // protege cache (lectura concurrente, escritura exclusiva)

	// sem limita el número de búsquedas concurrentes para no saturar el disco.
	sem chan struct{}
}

type cachedSearch struct {
	query   string
	results []*Result
	// exhaustive indica que el recorrido terminó antes de alcanzar el límite,
	// así que `results` es la lista completa de coincidencias.
	exhaustive bool
	// limit es el límite con el que se obtuvo `results`. Si una consulta
	// posterior pide menos, el resultado cacheado sigue siendo válido.
	limit int
}

// New crea un proveedor de archivos con concurrencia limitada.
func New() *Provider {
	// 8 búsquedas concurrentes por defecto: suficiente para aprovechar I/O
	// paralelo sin saturar el disco ni la CPU.
	return &Provider{
		cache: make(map[string]cachedSearch, 32),
		sem:   make(chan struct{}, 4),
	}
}

// maxDepth limita la profundidad de búsqueda para evitar recorrer
// directorios anidados demasiado profundos que ralentizan la búsqueda.
const maxDepth = 5

// maxCacheEntries tope de entradas en el caché de búsquedas recientes.
const maxCacheEntries = 32

// errLimitReached indica que ya se reunieron suficientes resultados.
var errLimitReached = fmt.Errorf("límite de resultados alcanzado")

// limitForQuery devuelve el límite adecuado según la longitud de la consulta.
// Consultas cortas (búsqueda progresiva) devuelven menos resultados para ser
// más rápidas; consultas largas devuelven más. Query vacío devuelve un
// listado inicial moderado.
func limitForQuery(query string, requested int) int {
	if requested > 0 {
		return requested
	}
	lenQ := len(strings.TrimSpace(query))
	if lenQ <= 2 {
		return 10 // pocas letras: pocos resultados, muy rápido
	}
	if lenQ <= 4 {
		return 20
	}
	return 50
}

// searchEmpty recorre el disco sin filtro de nombre y devuelve los primeros
// archivos encontrados (ordenados por ruta de WalkDir). Se usa para mostrar
// un listado inicial al abrir el menú de archivos sin haber escrito nada.
func (provider *Provider) searchEmpty(query, root string, limit int) ([]*Result, error) {
	var results []*Result

	rootDepth := strings.Count(root, string(os.PathSeparator))

	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		if d.IsDir() {
			if isExcludedDir(d.Name()) {
				return fs.SkipDir
			}
			depth := strings.Count(path, string(os.PathSeparator)) - rootDepth
			if depth > maxDepth {
				return fs.SkipDir
			}
			return nil
		}

		if !d.Type().IsRegular() {
			return nil
		}

		name := d.Name()
		if strings.HasPrefix(name, ".") {
			return nil
		}

		info, err := d.Info()
		if err != nil {
			return nil
		}

		results = append(results, newResult(path, name, info.Size()))

		if len(results) >= limit {
			return errLimitReached
		}
		return nil
	})

	if err != nil && err != errLimitReached {
		return nil, err
	}

	// Guardar en caché para la query vacía.
	exhaustive := len(results) < limit
	out := truncate(results, limit)
	provider.addToCache(query, out, limit, exhaustive)

	return out, nil
}

// isExcludedDir devuelve true si el directorio debe ser excluido por completo.
func isExcludedDir(name string) bool {
	// Directorios ocultos (empiezan con '.')
	if strings.HasPrefix(name, ".") {
		return true
	}
	// Directorios específicos no ocultos que no tienen sentido para el usuario
	switch name {
	case "node_modules", "__pycache__":
		return true
	}
	return false
}

// Search busca archivos cuyo nombre contenga query, bajo root (por defecto $HOME).
// La búsqueda es CONCURRENTE: los directorios de nivel superior se recorren en
// goroutines paralelas con un semáforo para controlar la carga de I/O.
//
// Para búsquedas progresivas: si hay un caché previo y la nueva query empieza
// por la query cacheada, se filtran los resultados cacheados en lugar de
// reescanear el disco (mucho más rápido al teclear letra a letra).
func (provider *Provider) Search(query, root string, limit int) ([]*Result, error) {
	if root == "" {
		root = os.Getenv("HOME")
		if root == "" {
			return nil, fmt.Errorf("HOME no definido")
		}
	}
	if query == "" {
		// Query vacía: devolver un listado inicial (primeros archivos
		// alfabéticamente en $HOME) para mostrar al abrir el menú de archivos.
		// No hay filtro de nombre, solo exclusiones y límite.
		limit = limitForQuery(query, limit)
		return provider.searchEmpty(query, root, limit)
	}
	qLower := strings.ToLower(query)
	effectiveLimit := limitForQuery(query, limit)

	// ── 1. Caché exacto (lectura concurrente) ───────────────────────
	provider.cacheMu.RLock()
	if cached, ok := provider.cache[query]; ok && cached.query == query &&
		(cached.exhaustive || cached.limit >= effectiveLimit) {
		provider.cacheMu.RUnlock()
		return truncate(cached.results, effectiveLimit), nil
	}
	provider.cacheMu.RUnlock()

	// ── 2. Búsqueda incremental: filtrar caché previo ───────────────
	// Buscar una entrada cacheada cuya query sea prefijo de la actual.
	// Así, al teclear "a" → "ab" → "abc", solo filtramos, no reescaneamos.
	// Solo sirve si el caché previo estaba completo: si se truncó al límite,
	// filtrarlo daría resultados incompletos.
	provider.cacheMu.RLock()
	var bestQuery string
	var bestCached []*Result
	for key, cached := range provider.cache {
		if !cached.exhaustive || key == query {
			continue
		}
		if strings.HasPrefix(qLower, strings.ToLower(cached.query)) && len(cached.results) > 0 {
			if len(cached.query) > len(bestQuery) {
				bestQuery = cached.query
				bestCached = cached.results
			}
		}
	}
	provider.cacheMu.RUnlock()

	if bestCached != nil {
		filtered := filterByQuery(bestCached, qLower)
		if len(filtered) > 0 {
			exhaustive := len(filtered) < effectiveLimit
			out := truncate(filtered, effectiveLimit)
			provider.addToCache(query, out, effectiveLimit, exhaustive)
			return out, nil
		}
	}

	// ── 3. Escanear disco en PARALELO (WalkDir concurrente) ─────────
	results := provider.searchParallel(root, qLower, effectiveLimit)

	// Guardar en caché. Se guarda acotado al límite para no retener listas
	// enormes; `exhaustive` se calcula antes de truncar.
	exhaustive := len(results) < effectiveLimit
	out := truncate(results, effectiveLimit)
	provider.addToCache(query, out, effectiveLimit, exhaustive)

	return out, nil
}

// searchParallel recorre el árbol de directorios en paralelo. Los directorios
// de nivel superior se procesan en goroutines independientes, cada una con su
// propio filepath.WalkDir. Los resultados se recolectan a través de un canal.
func (provider *Provider) searchParallel(root, qLower string, limit int) []*Result {
	// Adquirir semáforo para limitar búsquedas concurrentes.
	provider.sem <- struct{}{}
	defer func() { <-provider.sem }()

	// Leer las entradas de nivel superior de root.
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil
	}

	// Cada entrada de nivel superior que sea directorio (y no excluida) se
	// procesa en su propia goroutine. También procesamos los archivos de
	// nivel superior directamente.
	type dirJob struct {
		path string
	}

	var jobs []dirJob
	var rootFiles []*Result

	for _, entry := range entries {
		fullPath := filepath.Join(root, entry.Name())

		if entry.IsDir() {
			if isExcludedDir(entry.Name()) {
				continue
			}
			jobs = append(jobs, dirJob{path: fullPath})
		} else if entry.Type().IsRegular() {
			// Archivo de nivel superior: evaluar directamente.
			if strings.HasPrefix(entry.Name(), ".") {
				continue
			}
			if !strings.Contains(strings.ToLower(entry.Name()), qLower) {
				continue
			}
			info, err := entry.Info()
			if err != nil {
				continue
			}
			rootFiles = append(rootFiles, newResult(fullPath, entry.Name(), info.Size()))
			if len(rootFiles) >= limit {
				return rootFiles
			}
		}
	}

	if len(jobs) == 0 {
		return rootFiles
	}

	// Canal para recolectar resultados de las goroutines.
	type jobResult struct {
		dir  string
		list []*Result
		err  error
	}

	resultsCh := make(chan jobResult, len(jobs))
	var waitGroup sync.WaitGroup

	// Limitar paralelismo interno: no lanzar más de N goroutines a la vez.
	// Usamos un semáforo interno de workers.
	workerSem := make(chan struct{}, 8)

	for _, job := range jobs {
		workerSem <- struct{}{} // adquirir worker
		waitGroup.Add(1)
		go func(j dirJob) {
			defer func() { <-workerSem }() // liberar worker
			defer waitGroup.Done()

			list := provider.walkDir(j.path, rootDepth(root), qLower, limit)
			resultsCh <- jobResult{dir: j.path, list: list, err: nil}
		}(job)
	}

	// Cerrar resultsCh cuando terminen todos los workers.
	go func() {
		waitGroup.Wait()
		close(resultsCh)
	}()

	// Recolectar resultados.
	allResults := rootFiles
	for jobResult := range resultsCh {
		allResults = append(allResults, jobResult.list...)
		if len(allResults) >= limit {
			// Tenemos suficiente: cancelar los workers restantes drenando
			// el canal sin procesar más.
			for range resultsCh {
			}
			break
		}
	}

	return allResults
}

// rootDepth devuelve la profundidad de separadores de ruta de root.
func rootDepth(root string) int {
	return strings.Count(root, string(os.PathSeparator))
}

// walkDir recorre un directorio con filepath.WalkDir y devuelve los archivos
// que coinciden con la consulta. Se ejecuta en su propia goroutine.
func (provider *Provider) walkDir(dir string, rootDepth int, qLower string, limit int) []*Result {
	var results []*Result

	// filepath.WalkDir es síncrono pero solo recorre este subárbol, por lo que
	// no bloquea a otros directorios que se recorren en paralelo.
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // saltar no legibles
		}

		if d.IsDir() {
			// Excluir directorios ocultos y específicos no deseados.
			if isExcludedDir(d.Name()) {
				return fs.SkipDir
			}
			depth := strings.Count(path, string(os.PathSeparator)) - rootDepth
			if depth > maxDepth {
				return fs.SkipDir
			}
			return nil
		}

		// Solo archivos regulares: excluye symlinks.
		if !d.Type().IsRegular() {
			return nil
		}

		name := d.Name()
		// Excluir archivos ocultos.
		if strings.HasPrefix(name, ".") {
			return nil
		}

		// Búsqueda difusa.
		if !strings.Contains(strings.ToLower(name), qLower) {
			return nil
		}

		info, err := d.Info()
		if err != nil {
			return nil
		}

		results = append(results, newResult(path, name, info.Size()))

		if len(results) >= limit {
			return errLimitReached
		}
		return nil
	})

	if err != nil && err != errLimitReached {
		// Ignorar errores de walk: devolver lo que tengamos.
	}

	return results
}

// filterByQuery filtra resultados ya obtenidos por una nueva consulta (substring, sin mayúsculas).
func filterByQuery(results []*Result, qLower string) []*Result {
	out := make([]*Result, 0, len(results))
	for _, result := range results {
		if strings.Contains(strings.ToLower(result.Name), qLower) {
			out = append(out, result)
		}
	}
	return out
}

// truncate limita la cantidad de resultados.
func truncate(results []*Result, limit int) []*Result {
	if limit < 0 || len(results) <= limit {
		return results
	}
	return results[:limit]
}

// addToCache guarda una búsqueda en el caché, evictando la más antigua si se llena.
func (provider *Provider) addToCache(query string, results []*Result, limit int, exhaustive bool) {
	provider.cacheMu.Lock()
	defer provider.cacheMu.Unlock()
	if len(provider.cache) >= maxCacheEntries {
		// Evictar la primera entrada (FIFO simple).
		for k := range provider.cache {
			delete(provider.cache, k)
			break
		}
	}
	provider.cache[query] = cachedSearch{query: query, results: results, limit: limit, exhaustive: exhaustive}
}
