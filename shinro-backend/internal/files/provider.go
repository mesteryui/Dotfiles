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
	"context"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"shinro-backend/internal/logger"
	"shinro-backend/internal/safe"
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

	// gen se incrementa con cada cambio detectado en el sistema de archivos.
	// Las entradas de caché guardaron la generación con la que se
	// calcularon: si no coinciden con la actual, están obsoletas (el
	// fichero se creó, se borró o se movió) y hay que recalcular.
	gen atomic.Uint64

	// watcher vigila el árbol de directorios para detectar cambios. Es nil
	// si inotify no está disponible (entonces solo manda el TTL).
	watchMu   sync.Mutex
	watcher   *watcher
	watchRoot string

	// closed indica que el proveedor se ha cerrado: a partir de ese momento
	// no se vuelve a arrancar el vigilante (ni a recrearlo).
	closed bool

	// onChange se invoca (fuera de los locks) cuando el sistema de archivos
	// ha cambiado, para que quien lo use refresque lo que tenga en pantalla.
	onChangeMu sync.RWMutex
	onChange   func()

	// changeTimer agrupa los cambios que llegan seguidos: no se notifica en
	// cada evento, sino cuando la ráfaga se calma.
	changeMu      sync.Mutex
	changePending bool
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
	// gen es la generación del sistema de archivos con la que se calculó.
	gen uint64
	// at es el momento en que se calculó (para el TTL).
	at time.Time
}

// New crea un proveedor de archivos con concurrencia limitada.
func New() *Provider {
	// 4 búsquedas concurrentes por defecto: suficiente para aprovechar I/O
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

// cacheTTL es el tiempo máximo que se reutiliza un resultado cacheado.
//
// Es la red de seguridad para cuando el vigilante de cambios no está
// disponible (o no cubre un directorio, por estar más allá de la
// profundidad máxima): pasado ese tiempo la búsqueda se recalcula.
const cacheTTL = 20 * time.Second

// maxWatches es el tope de directorios vigilados simultáneamente. Es un
// límite generoso (el del kernel suele ser 524288) para no agotar los
// recursos del sistema.
const maxWatches = 4096

// filesChangeDebounce agrupa las ráfagas de cambios: al crear o borrar un
// fichero se disparan varios eventos seguidos, y notificar cada uno
// provocaría un rescaneo por cada uno.
const filesChangeDebounce = 500 * time.Millisecond

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
// archivos encontrados (ordenados por ruta de WalkDir). Se usa para mostrar un
// listado inicial al abrir el menú de archivos sin haber escrito nada.
func (provider *Provider) searchEmpty(ctx context.Context, query, root string, limit int) ([]*Result, error) {
	select {
	case provider.sem <- struct{}{}:
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	defer func() { <-provider.sem }()

	var results []*Result

	rootDepth := rootDepth(root)

	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		// Búsqueda cancelada (el cliente ya pidió otra query o se fue):
		// abandonar el recorrido en lugar de seguir gastando I/O.
		if ctx.Err() != nil {
			return ctx.Err()
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
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
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

// SetOnChange registra una función que se llama cuando el sistema de
// archivos ha cambiado (ficheros creados, borrados o movidos). La llamada
// se hace sin los locks del proveedor, así que puede buscar sin riesgo.
func (provider *Provider) SetOnChange(fn func()) {
	provider.onChangeMu.Lock()
	provider.onChange = fn
	provider.onChangeMu.Unlock()
}

// notifyChanged avisa al consumidor sin retener locks del proveedor.
func (provider *Provider) notifyChanged() {
	provider.onChangeMu.RLock()
	fn := provider.onChange
	provider.onChangeMu.RUnlock()
	if fn != nil {
		fn()
	}
}

// Generation devuelve la generación actual del sistema de archivos. Cada
// cambio detectado la incrementa.
func (provider *Provider) Generation() uint64 {
	return provider.gen.Load()
}

// handleFilesystemChange se llama cuando inotify avisa de un cambio.
//
// Lo primero es invalidar la caché (de inmediato: la siguiente búsqueda
// recalcula). La notificación a los suscriptores se agrupa con un pequeño
// debounce, para no lanzar un rescaneo por cada evento de una ráfaga de
// cambios.
func (provider *Provider) handleFilesystemChange() {
	provider.gen.Add(1)

	provider.changeMu.Lock()
	if provider.changePending {
		provider.changeMu.Unlock()
		return
	}
	provider.changePending = true
	provider.changeMu.Unlock()

	safe.Go("files.change", func() {
		time.Sleep(filesChangeDebounce)

		provider.changeMu.Lock()
		provider.changePending = false
		provider.changeMu.Unlock()

		provider.notifyChanged()
	})
}

// ensureWatcher arranca el vigilante del sistema de archivos (una sola vez)
// sobre el directorio donde se buscan los ficheros.
func (provider *Provider) ensureWatcher(root string) {
	if root == "" {
		return
	}

	provider.watchMu.Lock()
	// Tras un Close() el proveedor no vuelve a arrancar el vigilante.
	if provider.closed || provider.watcher != nil {
		provider.watchMu.Unlock()
		return
	}

	w, err := newWatcher(provider.handleFilesystemChange)
	if err != nil {
		provider.watchMu.Unlock()
		logger.Warn("files: vigilante de cambios no disponible", "error", err)
		return
	}

	provider.watcher = w
	provider.watchRoot = root
	provider.watchMu.Unlock()

	// Instalar las watches de forma síncrona respecto a la búsqueda: si se
	// hiciera en segundo plano, los cambios que ocurran entre la búsqueda y el
	// montaje del vigilante se pasarían por alto. El lock no se retiene durante
	// el recorrido para no bloquear otras búsquedas ni el cierre.
	w.watchTree(root)

	provider.watchMu.Lock()
	if provider.closed || provider.watcher != w {
		provider.watchMu.Unlock()
		w.close()
		return
	}
	provider.watchMu.Unlock()

	safe.Go("files.watch", func() { w.run() })

	logger.Info("files: vigilante de cambios activo", "root", root)
}

// Close detiene el vigilante de cambios y deja el proveedor cerrado: no se
// vuelve a arrancar el vigilante aunque después se busque algo.
func (provider *Provider) Close() {
	provider.watchMu.Lock()
	provider.closed = true
	w := provider.watcher
	provider.watcher = nil
	provider.watchMu.Unlock()

	if w != nil {
		w.close()
	}
}

// cacheValid indica si una entrada de caché sigue siendo válida.
//
// Deja de serlo si el sistema de archivos ha cambiado desde que se calculó
// (se creó, borró o movió algún fichero) o si ha pasado demasiado tiempo
// (por si el vigilante no cubría ese directorio).
func (provider *Provider) cacheValid(cached cachedSearch) bool {
	if cached.gen != provider.gen.Load() {
		return false
	}
	return time.Since(cached.at) < cacheTTL
}

// La búsqueda es CONCURRENTE: los directorios de nivel superior se recorren en
// goroutines paralelas con un semáforo para controlar la carga de I/O.
//
// Para búsquedas progresivas: si hay un caché previo y la nueva query empieza
// por la query cacheada, se filtran los resultados cacheados en lugar de
// reescanear el disco (mucho más rápido al teclear letra a letra).
func (provider *Provider) Search(query, root string, limit int) ([]*Result, error) {
	return provider.SearchContext(context.Background(), query, root, limit)
}

// SearchContext es Search con cancelación.
//
// El contexto permite abortar un recorrido cuando la petición ya no interesa
// (el usuario siguió tecleando o cerró la vista). Esto evita que se acumulen
// búsquedas recorriendo el disco a la vez, que es el mayor consumidor de I/O
// del backend.
func (provider *Provider) SearchContext(ctx context.Context, query, root string, limit int) ([]*Result, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if root == "" {
		root = os.Getenv("HOME")
		if root == "" {
			return nil, fmt.Errorf("HOME no definido")
		}
	}
	root = filepath.Clean(root)
	// Acotar el límite para evitar agotamiento de memoria por peticiones
	// maliciosas (DoS). El módulo de socket ya acota a 100; aquí se replica
	// por si se llama directamente al proveedor.
	if limit > 100 {
		limit = 100
	}
	if query == "" {
		// Query vacía: devolver un listado inicial (primeros archivos
		// alfabéticamente en $HOME) para mostrar al abrir el menú de archivos.
		// No hay filtro de nombre, solo exclusiones y límite.
		//
		// Se cachea igual que el resto para evitar recorrer $HOME una y
		// otra vez ante cada apertura o evento del vigilante. El vigilante
		// invalida la caché al cambiar el sistema de archivos.
		limit = limitForQuery(query, limit)
		provider.ensureWatcher(root)
		provider.cacheMu.RLock()
		if cached, ok := provider.cache[""]; ok && cached.query == "" &&
			(cached.exhaustive || cached.limit >= limit) &&
			provider.cacheValid(cached) {
			provider.cacheMu.RUnlock()
			return truncate(cached.results, limit), nil
		}
		provider.cacheMu.RUnlock()

		results, err := provider.searchEmpty(ctx, query, root, limit)
		if err != nil {
			return nil, err
		}
		exhaustive := len(results) < limit
		out := truncate(results, limit)
		provider.addToCache("", out, limit, exhaustive)
		return out, nil
	}
	qLower := strings.ToLower(query)
	effectiveLimit := limitForQuery(query, limit)

	// Arrancar (una sola vez) el vigilante de cambios del árbol de
	// ficheros: a partir de aquí, cada cambio invalida la caché.
	provider.ensureWatcher(root)

	// ── 1. Caché exacto (lectura concurrente) ───────────────────────
	provider.cacheMu.RLock()
	if cached, ok := provider.cache[query]; ok && cached.query == query &&
		(cached.exhaustive || cached.limit >= effectiveLimit) &&
		provider.cacheValid(cached) {
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
		if !provider.cacheValid(cached) {
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
	results := provider.searchParallel(ctx, root, qLower, effectiveLimit)

	// Una búsqueda cancelada no debe cachear un resultado vacío: si no, la
	// siguiente búsqueda de la misma query devolvería una lista vacía.
	if err := ctx.Err(); err != nil {
		return nil, err
	}

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
//
// El contexto cancela el recorrido: los workers abandonan su subárbol y el
// recolector deja de esperar en cuanto se cancela, de modo que no quedan
// goroutines ni lecturas de disco huérfanas.
func (provider *Provider) searchParallel(ctx context.Context, root, qLower string, limit int) []*Result {
	// Adquirir semáforo para limitar búsquedas concurrentes. Si se cancela
	// mientras esperamos hueco, no se empieza la búsqueda.
	select {
	case provider.sem <- struct{}{}:
	case <-ctx.Done():
		return nil
	}
	defer func() { <-provider.sem }()

	// Derivar un contexto cancelable para los workers: cuando se alcanza el
	// límite de resultados se cancela y los workers abandonan su subárbol en
	// lugar de seguir recorriendo el disco hasta el final.
	walkCtx, cancel := context.WithCancel(ctx)
	defer cancel()

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

jobsLoop:
	for _, job := range jobs {
		// No encolar más trabajo del que se puede ejecutar: si ya hay
		// suficientes workers ocupados, esperar a que uno se libere.
		select {
		case workerSem <- struct{}{}:
		case <-walkCtx.Done():
			break jobsLoop
		}
		waitGroup.Add(1)
		safe.Go("files.walk", func() {
			defer func() { <-workerSem }() // liberar worker
			defer waitGroup.Done()

			list := provider.walkDir(walkCtx, job.path, rootDepth(root), qLower, limit)
			select {
			case resultsCh <- jobResult{dir: job.path, list: list, err: nil}:
			case <-walkCtx.Done():
			}
		})
	}

	// Cerrar resultsCh cuando terminen todos los workers.
	safe.Go("files.collect", func() {
		waitGroup.Wait()
		close(resultsCh)
	})

	// Recolectar resultados.
	allResults := rootFiles
	for jobResult := range resultsCh {
		allResults = append(allResults, jobResult.list...)
		if len(allResults) >= limit {
			// Tenemos suficiente: cancelar los workers restantes para que
			// abandonen el recorrido del disco en lugar de seguir hasta el
			// final. resultsCh tiene capacidad para todos los jobs, así que
			// los envíos pendientes no se bloquean y el colector cierra el
			// canal al terminar.
			cancel()
			break
		}
	}

	return allResults
}

// rootDepth devuelve la profundidad de separadores de ruta de root.
func rootDepth(root string) int {
	cleaned := filepath.Clean(root)
	return strings.Count(cleaned, string(os.PathSeparator))
}

// walkDir recorre un directorio con filepath.WalkDir y devuelve los archivos
// que coinciden con la consulta. Se ejecuta en su propia goroutine.
//
// Si el contexto se cancela, el recorrido se abandona de inmediato.
func (provider *Provider) walkDir(ctx context.Context, dir string, rootDepth int, qLower string, limit int) []*Result {
	var results []*Result

	// filepath.WalkDir es síncrono pero solo recorre este subárbol, por lo que
	// no bloquea a otros directorios que se recorren en paralelo.
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // saltar no legibles
		}

		// Búsqueda cancelada: abandonar el subárbol.
		if ctx.Err() != nil {
			return ctx.Err()
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
//
// Nunca devuelve nil: un slice nil se serializaría como "null" y el cliente
// (QML) espera siempre un array, aunque esté vacío.
func truncate(results []*Result, limit int) []*Result {
	if results == nil {
		return []*Result{}
	}
	if limit < 0 || len(results) <= limit {
		return results
	}
	return results[:limit]
}

// addToCache guarda una búsqueda en el caché, evictando la más antigua si se llena.
// La entrada guarda la generación del sistema de archivos y el momento en que
// se calculó, para saber si sigue siendo válida.
func (provider *Provider) addToCache(query string, results []*Result, limit int, exhaustive bool) {
	provider.cacheMu.Lock()
	defer provider.cacheMu.Unlock()
	if len(provider.cache) >= maxCacheEntries {
		// Evictar la entrada más antigua. No se puede usar el orden de
		// iteración del mapa (es aleatorio en Go), así que se busca la de
		// menor "at": evictar una arbitraria tiraría la query que el
		// usuario acaba de teclear.
		var victim string
		var oldest time.Time
		for k, entry := range provider.cache {
			if victim == "" || entry.at.Before(oldest) {
				victim, oldest = k, entry.at
			}
		}
		if victim != "" {
			delete(provider.cache, victim)
		}
	}
	provider.cache[query] = cachedSearch{
		query:      query,
		results:    results,
		limit:      limit,
		exhaustive: exhaustive,
		gen:        provider.gen.Load(),
		at:         time.Now(),
	}
}
