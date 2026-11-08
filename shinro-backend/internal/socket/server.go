// Package socket implementa el servidor Unix socket llamado "shinro".
// Recibe mensajes JSON de Quickshell y empuja actualizaciones periódicas
// de system y weather a los clientes suscritos.
//
// El servidor mantiene la conexión abierta indefinidamente: solo el cliente
// decide cuándo cerrarla. Cada cliente es independiente, de modo que la
// desconexión de uno nunca afecta a los demás.
package socket

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"shinro-backend/internal/geo"
	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

// Server escucha en un socket Unix y distribuye datos por módulo.
type Server struct {
	path        string
	sysProvider *system.Provider
	wthProvider *weather.Provider
	geoProvider geo.Provider
	listener    net.Listener
	clients     map[*client]bool
	mu          sync.Mutex
}

func NewServer(sys *system.Provider, wth *weather.Provider, g geo.Provider) *Server {
	uid := os.Geteuid()
	path := "/run/user/" + strconv.Itoa(uid) + "/shinro"
	return &Server{
		path:        path,
		sysProvider: sys,
		wthProvider: wth,
		geoProvider: g,
		clients:     make(map[*client]bool),
	}
}

// Start arranca el servidor y bloquea hasta que el contexto se cancele.
func (s *Server) Start(ctx context.Context) error {
	dir := "/run/user/" + strconv.Itoa(os.Geteuid())
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}

	_ = os.Remove(s.path)
	ln, err := net.Listen("unix", s.path)
	if err != nil {
		return err
	}
	s.listener = ln
	if err := os.Chmod(s.path, 0660); err != nil {
		log.Printf("no se pudo establecer permisos del socket: %v", err)
	}

	log.Printf("shinro socket escuchando en %s", s.path)

	go s.acceptLoop(ctx)
	<-ctx.Done()
	_ = s.listener.Close()
	_ = os.Remove(s.path)
	return nil
}

type client struct {
	conn   net.Conn
	reader *bufio.Reader
	send   chan []byte
	done   chan struct{}

	closeOnce sync.Once
	mu        sync.Mutex

	subSys bool
	subWth bool
	intSys int // segundos
	intWth int
	city   string
	mode   geo.Mode
	lang   string

	// wake* despierta al pump para que relea su intervalo tras un hello.
	wakeSys chan struct{}
	wakeWth chan struct{}

	pumpSysStarted bool
	pumpWthStarted bool
}

func (c *client) signalSys() {
	select {
	case c.wakeSys <- struct{}{}:
	default:
	}
}

func (c *client) signalWth() {
	select {
	case c.wakeWth <- struct{}{}:
	default:
	}
}

// write encola un mensaje sin bloquearse si el cliente ya se fue.
func (c *client) write(msg []byte) {
	select {
	case <-c.done:
		return
	default:
	}

	select {
	case c.send <- msg:
	case <-c.done:
	default:
		// Cliente lento o saturado: descartar antes que bloquear el pump.
	}
}

// close cierra el cliente una sola vez. No se cierra el canal `send`:
// los pumps pueden seguir intentando escribir y verán `done` cerrado.
func (c *client) close() {
	c.closeOnce.Do(func() {
		close(c.done)
		_ = c.conn.Close()
	})
}

// acceptLoop acepta nuevas conexiones Unix.
func (s *Server) acceptLoop(ctx context.Context) {
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			select {
			case <-ctx.Done():
				return
			default:
				log.Printf("error aceptando conexión: %v", err)
				continue
			}
		}

		c := &client{
			conn:    conn,
			reader:  bufio.NewReader(conn),
			send:    make(chan []byte, 128),
			done:    make(chan struct{}),
			wakeSys: make(chan struct{}, 1),
			wakeWth: make(chan struct{}, 1),
		}

		s.mu.Lock()
		s.clients[c] = true
		s.mu.Unlock()

		log.Printf("cliente conectado desde %s", conn.RemoteAddr())
		go c.writeLoop()
		go s.readLoop(c)
	}
}

func (c *client) writeLoop() {
	for {
		select {
		case <-c.done:
			return
		case msg := <-c.send:
			if _, err := c.conn.Write(append(msg, '\n')); err != nil {
				// El cliente se fue: cerrar solo este cliente.
				log.Printf("cliente %s: error de escritura: %v", c.conn.RemoteAddr(), err)
				c.close()
				return
			}
		}
	}
}

func (s *Server) readLoop(c *client) {
	defer func() {
		c.close()
		s.mu.Lock()
		delete(s.clients, c)
		s.mu.Unlock()
		log.Println("cliente desconectado")
	}()

	for {
		line, err := c.reader.ReadString('\n')
		if err != nil {
			if errors.Is(err, io.EOF) {
				log.Printf("cliente %s: EOF (el cliente cerró)", c.conn.RemoteAddr())
				return
			}
			log.Printf("cliente %s: lectura terminada: %v", c.conn.RemoteAddr(), err)
			return
		}

		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		var raw map[string]json.RawMessage
		if err := json.Unmarshal([]byte(line), &raw); err != nil {
			log.Printf("no se pudo parsear JSON: %v, línea: %s", err, line)
			continue
		}

		var msgType string
		_ = json.Unmarshal(raw["type"], &msgType)

		switch msgType {
		case "hello":
			s.handleHello(c, raw)
		case "get":
			s.handleGet(c, raw)
		default:
			log.Printf("mensaje desconocido: %s", msgType)
		}
	}
}

// handleHello procesa el handshake, responde y arranca el empuje periódico.
func (s *Server) handleHello(c *client, raw map[string]json.RawMessage) {
	var payload struct {
		Location struct {
			Mode string `json:"mode"`
			City string `json:"city"`
		} `json:"location"`
		Intervals struct {
			System  int `json:"system"`
			Weather int `json:"weather"`
		} `json:"intervals"`
		Lang string `json:"lang"`
	}
	if locRaw, ok := raw["location"]; ok {
		_ = json.Unmarshal(locRaw, &payload.Location)
	}
	if intRaw, ok := raw["intervals"]; ok {
		_ = json.Unmarshal(intRaw, &payload.Intervals)
	}

	c.mu.Lock()
	c.city = payload.Location.City
	c.lang = payload.Lang
	if c.lang == "" {
		c.lang = "es"
	}
	// Solo los clientes suscritos a weather definen la ubicación. Un cliente
	// de solo-system (p. ej. SystemInfoService) no debe sobrescribir la
	// ciudad/modo que usa el clima.
	if payload.Intervals.Weather > 0 {
		if payload.Location.Mode == string(geo.ModeAuto) {
			c.mode = geo.ModeAuto
		} else {
			c.mode = geo.ModeManual
		}
	} else {
		c.mode = geo.ModeManual
	}
	c.intSys = payload.Intervals.System
	c.intWth = payload.Intervals.Weather
	c.subSys = c.intSys > 0
	c.subWth = c.intWth > 0

	startSys := c.subSys && !c.pumpSysStarted
	startWth := c.subWth && !c.pumpWthStarted
	if startSys {
		c.pumpSysStarted = true
	}
	if startWth {
		c.pumpWthStarted = true
	}
	// Si el pump ya estaba vivo, despertarlo para que reevalúe el intervalo
	// (cambio de reloadTime) o termine si la suscripción pasó a 0.
	wakeSys := c.pumpSysStarted && !startSys
	wakeWth := c.pumpWthStarted && !startWth

	intSys, intWth := c.intSys, c.intWth
	mode, city := c.mode, c.city
	subSys, subWth := c.subSys, c.subWth
	c.mu.Unlock()

	// La ubicación compartida se actualiza fuera de c.mu: SetAuto puede
	// tardar (D-Bus) y no debe bloquear el pump de este cliente.
	if subWth {
		if payload.Location.Mode == string(geo.ModeAuto) {
			s.geoProvider.SetAuto(payload.Location.City)
		} else {
			s.geoProvider.SetManual(payload.Location.City)
		}
	}

	log.Printf("handshake: mode=%s city=%s intervals={system:%d weather:%d}",
		mode, city, intSys, intWth)

	resp, _ := json.Marshal(map[string]interface{}{
		"type": "hello",
		"ok":   true,
		"mode": mode,
		"city": city,
	})
	c.write(resp)

	// Snapshot inmediato: la UI se rellena sin esperar al primer tick.
	if subSys {
		s.sendSystem(c)
	}
	if subWth {
		s.sendWeather(c)
	}

	if startSys {
		go s.pumpSystem(c)
	}
	if startWth {
		go s.pumpWeather(c)
	}
	if wakeSys {
		c.signalSys()
	}
	if wakeWth {
		c.signalWth()
	}
}

// handleGet responde con un snapshot inmediato del módulo pedido.
// Es opcional (el flujo normal es push tras hello), pero útil para depurar.
func (s *Server) handleGet(c *client, raw map[string]json.RawMessage) {
	var module string
	if modRaw, ok := raw["module"]; ok {
		_ = json.Unmarshal(modRaw, &module)
	}
	log.Printf("get request: module=%s", module)

	switch module {
	case "system":
		s.sendSystem(c)
	case "weather":
		s.sendWeather(c)
	default:
		s.sendError(c, "módulo desconocido: "+module)
	}
}

// pumpSystem envía actualizaciones de system según el intervalo actual.
// El intervalo se relee en cada vuelta para que un hello pueda cambiarlo
// sin reconectar; un intervalo <= 0 termina el pump.
func (s *Server) pumpSystem(c *client) {
	defer func() {
		c.mu.Lock()
		c.pumpSysStarted = false
		c.mu.Unlock()
	}()

	for {
		c.mu.Lock()
		interval := c.intSys
		c.mu.Unlock()
		if interval <= 0 {
			return
		}

		timer := time.NewTimer(time.Duration(interval) * time.Second)
		select {
		case <-c.done:
			timer.Stop()
			return
		case <-c.wakeSys:
			timer.Stop()
		case <-timer.C:
			s.sendSystem(c)
		}
	}
}

// pumpWeather envía actualizaciones de weather según el intervalo actual.
func (s *Server) pumpWeather(c *client) {
	defer func() {
		c.mu.Lock()
		c.pumpWthStarted = false
		c.mu.Unlock()
	}()

	for {
		c.mu.Lock()
		interval := c.intWth
		c.mu.Unlock()
		if interval <= 0 {
			return
		}

		timer := time.NewTimer(time.Duration(interval) * time.Second)
		select {
		case <-c.done:
			timer.Stop()
			return
		case <-c.wakeWth:
			timer.Stop()
		case <-timer.C:
			s.sendWeather(c)
		}
	}
}

func (s *Server) sendSystem(c *client) {
	stats, err := s.sysProvider.Stats()
	if err != nil {
		s.sendError(c, "error leyendo system: "+err.Error())
		return
	}
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "system",
		"data":   stats,
	})
	c.write(msg)
}

func (s *Server) sendWeather(c *client) {
	c.mu.Lock()
	city := c.city
	lang := c.lang
	c.mu.Unlock()
	if lang == "" {
		lang = "es"
	}

	w, err := s.wthProvider.Snapshot(lang)
	if err != nil {
		s.sendError(c, "error leyendo weather: "+err.Error())
		return
	}

	if city != "" {
		if w.City == "" {
			w.City = city
		}
		if w.CityLabel == "" {
			w.CityLabel = city
		}
	}

	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "weather",
		"data":   w,
	})
	c.write(msg)
}

func (s *Server) sendError(c *client, message string) {
	msg, _ := json.Marshal(map[string]string{
		"type":    "error",
		"message": message,
	})
	c.write(msg)
}
