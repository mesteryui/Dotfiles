// Acceso nativo al portapapeles Wayland mediante los protocolos de
// control de datos (data-control).
//
// Soporta, por orden de preferencia:
//  1. ext_data_control_manager_v1 (estándar, GNOME ≥ 49, KWin, Sway, Hyprland…)
//  2. zwlr_data_control_manager_v1 (wlroots, deprecado pero muy extendido)
//
// Ambos son estructuralmente idénticos; solo cambia el nombre de la interfaz
// global y, en zwlr, la selección primaria requiere versión ≥ 2.
//
// A diferencia de wl-copy/wl-paste, este cliente habla el protocolo por el
// socket Wayland directamente: net.UnixConn para el transporte y SCM_RIGHTS
// para los pipes por los que viajan los datos. Ventajas para un servicio en
// segundo plano:
//   - No depende de procesos externos ni del entorno que hereden.
//   - data-control permite leer la selección sin tener focoffer.
//   - Mientras el backend viva, él mismo posee la selección: no hace falta
//     wl-clip-persist.
//   - Los cambios llegan como eventos (data_offer/selection), sin polling.
//
// Solo se implementan los objetos y opcodes que usa el portapapeles; el resto
// del protocolo Wayland se ignora.
package clipboard

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"shinro-backend/internal/logger"
	"shinro-backend/internal/safe"
)

// Selección a la que se refiere una operación.
type selType int

const (
	selClipboard selType = iota
	selPrimary
)

// Opcodes del subconjunto del protocolo que usamos.
// ext-data-control-v1 y zwlr-data-control-v1 son estructuralmente idénticos
// (ext fue modelado sobre wlroots), así que los mismos opcodes sirven para
// ambos. Solo cambian los nombres de interfaz al hacer bind.
const (
	wlDisplayID = 1

	wlDisplayOpError    = 0
	wlDisplayOpDeleteID = 1

	wlDisplayReqSync        = 0
	wlDisplayReqGetRegistry = 1

	wlRegistryReqBind        = 0
	wlRegistryEvGlobal       = 0
	wlRegistryEvGlobalRemove = 1

	// data-control manager
	dcManagerReqCreateSource = 0
	dcManagerReqGetDevice    = 1

	// data-control device
	dcDeviceReqSetSelection        = 0
	dcDeviceReqSetPrimarySelection = 2 // solo ext v1 o zwlr ≥ 2
	dcDeviceEvDataOffer            = 0
	dcDeviceEvSelection            = 1
	dcDeviceEvPrimarySelection     = 3 // solo ext v1 o zwlr ≥ 2
	dcDeviceEvFinished             = 2

	// data-control source
	dcSourceReqOffer    = 0
	dcSourceReqDestroy  = 1
	dcSourceEvSend      = 0
	dcSourceEvCancelled = 1

	// data-control offer
	dcOfferReqReceive = 0
	dcOfferReqDestroy = 1
	dcOfferEvOffer    = 0

	wlCallbackEvDone = 0
)

var errWLClosed = errors.New("cliente Wayland cerrado")

// wlTrace imprime el tráfico del protocolo cuando SHINRO_WL_TRACE=1. Sirve
// para depurar el wire format sin wireshark.
var wlTrace = os.Getenv("SHINRO_WL_TRACE") != ""

// ── codec del wire format ───────────────────────────────────────
// Cada mensaje: cabecera de 8 bytes (id u32, size<<16|opcode u32) seguida de
// argumentos alineados a 4 bytes. Los descriptores viajan fuera de banda.

type wlEncoder struct{ buf []byte }

func (e *wlEncoder) u32(v uint32) {
	var b [4]byte
	binary.LittleEndian.PutUint32(b[:], v)
	e.buf = append(e.buf, b[:]...)
}

func (e *wlEncoder) str(s string) {
	e.u32(uint32(len(s) + 1))
	e.buf = append(e.buf, s...)
	e.buf = append(e.buf, 0)
	for len(e.buf)%4 != 0 {
		e.buf = append(e.buf, 0)
	}
}

type wlDecoder struct {
	buf []byte
	off int
}

func (d *wlDecoder) u32() uint32 {
	if d.off+4 > len(d.buf) {
		d.off = len(d.buf)
		return 0
	}
	v := binary.LittleEndian.Uint32(d.buf[d.off:])
	d.off += 4
	return v
}

func (d *wlDecoder) str() string {
	n := int(d.u32())
	if n <= 0 || d.off+n > len(d.buf) {
		d.off = len(d.buf)
		return ""
	}
	s := string(d.buf[d.off : d.off+n-1])
	d.off += n
	for d.off%4 != 0 {
		d.off++
	}
	return s
}

type wlConn struct {
	conn    *net.UnixConn
	writeMu sync.Mutex
}

func (conexion *wlConn) send(id uint32, opcode uint16, args []byte, fds []int) error {
	size := 8 + len(args)
	msg := make([]byte, size)
	binary.LittleEndian.PutUint32(msg[0:4], id)
	binary.LittleEndian.PutUint32(msg[4:8], uint32(size)<<16|uint32(opcode))
	copy(msg[8:], args)

	conexion.writeMu.Lock()
	defer conexion.writeMu.Unlock()
	if wlTrace {
		fmt.Fprintf(os.Stderr, "wl SEND id=%d op=%d size=%d args=%x\n", id, opcode, size, args)
	}
	if len(fds) > 0 {
		oob := syscall.UnixRights(fds...)
		_, _, err := conexion.conn.WriteMsgUnix(msg, oob, nil)
		return err
	}
	_, err := conexion.conn.Write(msg)
	return err
}

// ── cliente ────────────────────────────────────────────────────

type wlGlobal struct {
	name    uint32
	iface   string
	version uint32
}

type wlHandler func(opcode uint16, d *wlDecoder)

type wlOffer struct {
	id uint32

	mu          sync.Mutex
	mimes       []string
	inUse       int
	destroyed   bool
	destroySent bool
}

type wlSource struct {
	id    uint32
	mimes []string
	data  []byte
	hash  uint64
	sel   selType // selección a la que pertenece esta fuente
}

// wlDevice representa un data device de un asiento, ya sea para la selección
// del portapapeles o para la selección primaria.
type wlDevice struct {
	id         uint32
	sel        selType
	handlerSet bool // si ya se envió set_selection con source != nil
}

type wlClient struct {
	conn *wlConn

	mu             sync.Mutex
	nextID         uint32
	handlers       map[uint32]wlHandler
	globals        map[uint32]wlGlobal
	offers         map[uint32]*wlOffer
	current        *wlOffer // oferta actual de la selección del portapapeles
	currentPrimary *wlOffer // oferta actual de la selección primaria
	source         *wlSource
	err            error

	fdMu       sync.Mutex
	pendingFDs []int

	done      chan struct{}
	closeOnce sync.Once
	notify    chan struct{}

	managerID      uint32
	registryID     uint32
	managerIface   string // "ext" o "zwlr"
	managerVersion uint32
	devices        []wlDevice // dispositivos regulares (uno por asiento)
	primaryDevices []wlDevice // dispositivos primarios (uno por asiento, si disponible)
}

// dialWL conecta con el compositor y prepara el data device de cada asientoffer.
func dialWL() (*wlClient, error) {
	display := waylandDisplay()
	if display == "" {
		return nil, errors.New("WAYLAND_DISPLAY no disponible")
	}
	path := display
	if !filepath.IsAbs(path) {
		rt := os.Getenv("XDG_RUNTIME_DIR")
		if rt == "" {
			return nil, errors.New("XDG_RUNTIME_DIR no definido")
		}
		path = filepath.Join(rt, display)
	}

	conn, err := net.DialUnix("unix", nil, &net.UnixAddr{Name: path, Net: "unix"})
	if err != nil {
		return nil, fmt.Errorf("conectar con Wayland (%s): %w", path, err)
	}

	cliente := &wlClient{
		conn:     &wlConn{conn: conn},
		nextID:   2,
		handlers: make(map[uint32]wlHandler),
		globals:  make(map[uint32]wlGlobal),
		offers:   make(map[uint32]*wlOffer),
		done:     make(chan struct{}),
		notify:   make(chan struct{}, 1),
	}
	cliente.handlers[wlDisplayID] = cliente.handleDisplay
	safe.Go("wayland.read", func() { cliente.readLoop() })

	if err := cliente.init(); err != nil {
		cliente.Close()
		return nil, err
	}
	return cliente, nil
}

func (cliente *wlClient) init() error {
	regID := cliente.allocID()
	cliente.registryID = regID
	cliente.setHandler(regID, cliente.handleRegistry)
	enc := &wlEncoder{}
	enc.u32(regID)
	if err := cliente.conn.send(wlDisplayID, wlDisplayReqGetRegistry, enc.buf, nil); err != nil {
		return err
	}
	if err := cliente.roundtrip(); err != nil {
		return err
	}

	var seats []wlGlobal
	var extMgr *wlGlobal
	var zwlrMgr *wlGlobal
	for _, g := range cliente.snapshotGlobals() {
		switch g.iface {
		case "wl_seat":
			seats = append(seats, g)
		case "ext_data_control_manager_v1":
			gg := g
			extMgr = &gg
		case "zwlr_data_control_manager_v1":
			gg := g
			zwlrMgr = &gg
		}
	}

	var manager *wlGlobal
	var iface string
	var version uint32
	if extMgr != nil {
		// ext-data-control es el estándar; lo preferimos.
		manager = extMgr
		iface = "ext"
		version = min(extMgr.version, 1)
	} else if zwlrMgr != nil {
		manager = zwlrMgr
		iface = "zwlr"
		version = min(zwlrMgr.version, 2)
	} else {
		return errors.New("el compositor no ofrece ext_data_control_manager_v1 ni zwlr_data_control_manager_v1")
	}
	if len(seats) == 0 {
		return errors.New("el compositor no ofrece wl_seat")
	}

	cliente.managerIface = iface
	cliente.managerVersion = version

	mgrID, err := cliente.bind(manager.name, manager.iface, version)
	if err != nil {
		return err
	}
	cliente.managerID = mgrID

	for _, seat := range seats {
		seatID, err := cliente.bind(seat.name, seat.iface, min(seat.version, 5))
		if err != nil {
			return err
		}
		// Dispositivo para la selección del portapapeles.
		devID := cliente.allocID()
		cliente.setHandler(devID, func(op uint16, decoder *wlDecoder) {
			cliente.handleDevice(selClipboard, op, decoder)
		})
		enc := &wlEncoder{}
		enc.u32(devID)
		enc.u32(seatID)
		if err := cliente.conn.send(mgrID, dcManagerReqGetDevice, enc.buf, nil); err != nil {
			return err
		}
		cliente.devices = append(cliente.devices, wlDevice{id: devID, sel: selClipboard})

		// Dispositivo para la selección primaria (si el protocolo lo soporta).
		//
		// PENDIENTE: se crea el device y se registra su handler, pero el
		// backend todavía no usa la selección primaria: no envía
		// set_primary_selection ni la lee. Está preparado para cuando la
		// interfaz de la shell lo necesite.
		supportsPrimary := (iface == "ext") || (iface == "zwlr" && version >= 2)
		if supportsPrimary {
			primID := cliente.allocID()
			cliente.setHandler(primID, func(op uint16, decoder *wlDecoder) {
				cliente.handleDevice(selPrimary, op, decoder)
			})
			enc = &wlEncoder{}
			enc.u32(primID)
			enc.u32(seatID)
			if err := cliente.conn.send(mgrID, dcManagerReqGetDevice, enc.buf, nil); err != nil {
				return err
			}
			cliente.primaryDevices = append(cliente.primaryDevices, wlDevice{id: primID, sel: selPrimary})
		}
	}
	return nil
}

func (cliente *wlClient) bind(name uint32, iface string, version uint32) (uint32, error) {
	id := cliente.allocID()
	enc := &wlEncoder{}
	enc.u32(name)
	enc.str(iface)
	enc.u32(version)
	enc.u32(id)
	if err := cliente.conn.send(cliente.registryID, wlRegistryReqBind, enc.buf, nil); err != nil {
		return 0, err
	}
	return id, nil
}

func (cliente *wlClient) roundtrip() error {
	id := cliente.allocID()
	done := make(chan struct{})
	var once sync.Once
	cliente.setHandler(id, func(op uint16, d *wlDecoder) {
		if op == wlCallbackEvDone {
			once.Do(func() { close(done) })
		}
	})
	defer cliente.dropHandler(id)

	enc := &wlEncoder{}
	enc.u32(id)
	if err := cliente.conn.send(wlDisplayID, wlDisplayReqSync, enc.buf, nil); err != nil {
		return err
	}

	select {
	case <-done:
		return nil
	case <-cliente.done:
		return cliente.Err()
	case <-time.After(clipCmdTimeout):
		return errors.New("tiempo de espera agotado en el roundtrip de Wayland")
	}
}

// Run mantiene el cliente vivo y llama a onSelection cada vez que cambia la
// selección del portapapeles o la selección primaria. Devuelve cuando se
// cancela el contexto o se pierde la conexión.
func (cliente *wlClient) Run(ctx context.Context, onSelection func()) error {
	for {
		select {
		case <-ctx.Done():
			cliente.Close()
			return nil
		case <-cliente.done:
			return cliente.Err()
		case <-cliente.notify:
			if onSelection != nil {
				onSelection()
			}
		}
	}
}

// ReadCurrent devuelve el contenido actual del portapapeles. Prefiere texto y,
// si no lo hay, una imagen. ok=false si la selección está vacía o no ofrece
// ningún tipo que sepamos manejar.
func (cliente *wlClient) ReadCurrent() (mime string, data []byte, ok bool, err error) {
	offer := cliente.acquireOffer(selClipboard)
	if offer == nil {
		return "", nil, false, nil
	}
	defer cliente.releaseOffer(offer)

	// Los mime types suelen llegar justo después de data_offer; si el evento
	// selection nos despertó antes, esperamos un instante.
	deadline := time.Now().Add(500 * time.Millisecond)
	var mimes []string
	for {
		offer.mu.Lock()
		mimes = append(mimes[:0], offer.mimes...)
		offer.mu.Unlock()
		if len(mimes) > 0 || time.Now().After(deadline) {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}

	mime = chooseMime(mimes)
	if mime == "" {
		return "", nil, false, nil
	}
	data, err = cliente.receive(offer.id, mime)
	if err != nil {
		return mime, nil, false, err
	}
	return mime, data, true, nil
}

// PENDIENTE: sin llamadas desde el backend.
//
// ReadPrimary devuelve el contenido actual de la selección primaria
// (middle-click). Same semantics as ReadCurrent.
//
// El backend solo gestiona la selección del portapapeles; la primaria se
// deja preparada para cuando haga falta.
func (cliente *wlClient) ReadPrimary() (mime string, data []byte, ok bool, err error) {
	offer := cliente.acquireOffer(selPrimary)
	if offer == nil {
		return "", nil, false, nil
	}
	defer cliente.releaseOffer(offer)

	deadline := time.Now().Add(500 * time.Millisecond)
	var mimes []string
	for {
		offer.mu.Lock()
		mimes = append(mimes[:0], offer.mimes...)
		offer.mu.Unlock()
		if len(mimes) > 0 || time.Now().After(deadline) {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}

	mime = chooseMime(mimes)
	if mime == "" {
		return "", nil, false, nil
	}
	data, err = cliente.receive(offer.id, mime)
	if err != nil {
		return mime, nil, false, err
	}
	return mime, data, true, nil
}

// SetSelection pasa a ser dueño de la selección del portapapeles con el mime y
// datos dados.
func (cliente *wlClient) SetSelection(mime string, data []byte) error {
	return cliente.setSelection(selClipboard, mime, data)
}

// PENDIENTE: sin llamadas desde el backend.
//
// SetPrimarySelection pasa a ser dueño de la selección primaria con el mime y
// datos dados.
//
// El backend solo gestiona la selección del portapapeles; la primaria se
// deja preparada para cuando haga falta.
func (cliente *wlClient) SetPrimarySelection(mime string, data []byte) error {
	return cliente.setSelection(selPrimary, mime, data)
}

func (cliente *wlClient) setSelection(sel selType, mime string, data []byte) error {
	cliente.mu.Lock()
	var dev uint32
	var mgr uint32
	switch sel {
	case selClipboard:
		if len(cliente.devices) > 0 {
			dev = cliente.devices[0].id
		}
	case selPrimary:
		if len(cliente.primaryDevices) > 0 {
			dev = cliente.primaryDevices[0].id
		}
	}
	mgr = cliente.managerID
	cliente.mu.Unlock()
	if dev == 0 || mgr == 0 {
		return fmt.Errorf("Wayland: no hay data device para %s", selName(sel))
	}

	src := &wlSource{
		id:    cliente.allocID(),
		mimes: mimesFor(mime),
		data:  data,
		hash:  clipHash(data),
		sel:   sel,
	}
	cliente.setHandler(src.id, func(op uint16, d *wlDecoder) {
		switch op {
		case dcSourceEvSend:
			_ = d.str() // mime solicitado; ofrecemos los mismos bytes
			fd := cliente.popFD()
			if fd < 0 {
				logger.Warn("clipboard: petición de datos sin descriptor")
				return
			}
			safe.Go("wayland.serve", func() { serveSource(fd, src.data) })
		case dcSourceEvCancelled:
			cliente.clearSource(src)
		}
	})

	cliente.mu.Lock()
	cliente.source = src
	cliente.mu.Unlock()

	enc := &wlEncoder{}
	enc.u32(src.id)
	if err := cliente.conn.send(mgr, dcManagerReqCreateSource, enc.buf, nil); err != nil {
		return err
	}
	for _, m := range src.mimes {
		enc = &wlEncoder{}
		enc.str(m)
		if err := cliente.conn.send(src.id, dcSourceReqOffer, enc.buf, nil); err != nil {
			return err
		}
	}
	enc = &wlEncoder{}
	enc.u32(src.id)
	var reqOpcode uint16
	switch sel {
	case selClipboard:
		reqOpcode = dcDeviceReqSetSelection
	case selPrimary:
		reqOpcode = dcDeviceReqSetPrimarySelection
	}
	return cliente.conn.send(dev, reqOpcode, enc.buf, nil)
}

// selName devuelve el nombre legible de un tipo de selección.
func selName(sel selType) string {
	switch sel {
	case selClipboard:
		return "portapapeles"
	case selPrimary:
		return "primaria"
	}
	return "desconocida"
}

// owns indica si el hash corresponde a la selección que posee este cliente.
// Evita reingerir como "externa" una copia hecha por el propio backend.
func (cliente *wlClient) owns(hash uint64) bool {
	cliente.mu.Lock()
	src := cliente.source
	cliente.mu.Unlock()
	return src != nil && src.hash == hash
}

// Close cierra la conexión y libera descriptores pendientes.
func (cliente *wlClient) Close() { cliente.fail(errWLClosed) }

func (cliente *wlClient) Err() error {
	cliente.mu.Lock()
	defer cliente.mu.Unlock()
	return cliente.err
}

// ── bucle de lectura y despacho ─────────────────────────────────

func (cliente *wlClient) readLoop() {
	buf := make([]byte, 0, 8192)
	tmp := make([]byte, 64*1024)
	oob := make([]byte, 4096)

	for {
		n, oobn, _, _, err := cliente.conn.conn.ReadMsgUnix(tmp, oob)
		if err != nil {
			cliente.fail(err)
			return
		}
		if oobn > 0 {
			fds, err := parseOOB(oob[:oobn])
			if err != nil {
				cliente.fail(err)
				return
			}
			cliente.pushFDs(fds)
		}

		buf = append(buf, tmp[:n]...)
		for len(buf) >= 8 {
			id := binary.LittleEndian.Uint32(buf[0:4])
			word := binary.LittleEndian.Uint32(buf[4:8])
			size := int(word >> 16)
			opcode := uint16(word & 0xffff)
			if size < 8 {
				cliente.fail(fmt.Errorf("mensaje Wayland inválido (tamaño %d)", size))
				return
			}
			if len(buf) < size {
				break
			}
			if wlTrace {
				fmt.Fprintf(os.Stderr, "wl RECV id=%d op=%d size=%d payload=%x\n", id, opcode, size, buf[8:size])
			}
			if h := cliente.getHandler(id); h != nil {
				h(opcode, &wlDecoder{buf: buf[8:size]})
			}
			buf = buf[size:]
		}
		if len(buf) == 0 {
			buf = buf[:0]
		}
	}
}

func (cliente *wlClient) handleDisplay(op uint16, d *wlDecoder) {
	switch op {
	case wlDisplayOpError:
		obj := d.u32()
		code := d.u32()
		msg := d.str()
		cliente.fail(fmt.Errorf("error del compositor Wayland (objeto %d, código %d): %s", obj, code, msg))
	case wlDisplayOpDeleteID:
		_ = d.u32()
	}
}

func (cliente *wlClient) handleRegistry(op uint16, d *wlDecoder) {
	switch op {
	case wlRegistryEvGlobal:
		name := d.u32()
		iface := d.str()
		ver := d.u32()
		cliente.mu.Lock()
		cliente.globals[name] = wlGlobal{name: name, iface: iface, version: ver}
		cliente.mu.Unlock()
	case wlRegistryEvGlobalRemove:
		name := d.u32()
		cliente.mu.Lock()
		delete(cliente.globals, name)
		cliente.mu.Unlock()
	}
}

func (cliente *wlClient) handleDevice(sel selType, op uint16, d *wlDecoder) {
	switch op {
	case dcDeviceEvDataOffer:
		id := d.u32()
		offer := &wlOffer{id: id}
		cliente.mu.Lock()
		cliente.offers[id] = offer
		cliente.mu.Unlock()
		cliente.setHandler(id, func(op uint16, d *wlDecoder) {
			if op != dcOfferEvOffer {
				return
			}
			mime := d.str()
			offer.mu.Lock()
			offer.mimes = append(offer.mimes, mime)
			offer.mu.Unlock()
		})

	case dcDeviceEvSelection:
		id := d.u32()
		var next *wlOffer
		if id != 0 {
			cliente.mu.Lock()
			next = cliente.offers[id]
			cliente.mu.Unlock()
		}
		cliente.mu.Lock()
		old := cliente.current
		cliente.current = next
		cliente.mu.Unlock()
		if old != nil && old != next {
			cliente.destroyOffer(old)
		}
		if next != nil {
			select {
			case cliente.notify <- struct{}{}:
			default:
			}
		}

	case dcDeviceEvPrimarySelection:
		id := d.u32()
		var next *wlOffer
		if id != 0 {
			cliente.mu.Lock()
			next = cliente.offers[id]
			cliente.mu.Unlock()
		}
		cliente.mu.Lock()
		old := cliente.currentPrimary
		cliente.currentPrimary = next
		cliente.mu.Unlock()
		if old != nil && old != next {
			cliente.destroyOffer(old)
		}
		if next != nil {
			select {
			case cliente.notify <- struct{}{}:
			default:
			}
		}

	case dcDeviceEvFinished:
		cliente.fail(errors.New("el compositor retiró el data device"))
	}
}

// currentID se eliminó: los eventos se despachan mediante closures por
// dispositivo que capturan el tipo de selección, así que no hace falta
// leer el id del objeto desde el decoder.

// ── ofertas ─────────────────────────────────────────────────────

func (cliente *wlClient) acquireOffer(sel selType) *wlOffer {
	cliente.mu.Lock()
	var offer *wlOffer
	switch sel {
	case selClipboard:
		offer = cliente.current
	case selPrimary:
		offer = cliente.currentPrimary
	}
	cliente.mu.Unlock()
	if offer == nil {
		return nil
	}
	offer.mu.Lock()
	defer offer.mu.Unlock()
	if offer.destroyed {
		return nil
	}
	offer.inUse++
	return offer
}

func (cliente *wlClient) releaseOffer(offer *wlOffer) {
	offer.mu.Lock()
	if offer.inUse > 0 {
		offer.inUse--
	}
	offer.mu.Unlock()
	cliente.maybeDestroyOffer(offer)
}

func (cliente *wlClient) destroyOffer(offer *wlOffer) {
	offer.mu.Lock()
	offer.destroyed = true
	offer.mu.Unlock()
	cliente.maybeDestroyOffer(offer)
}

func (cliente *wlClient) maybeDestroyOffer(offer *wlOffer) {
	offer.mu.Lock()
	if !offer.destroyed || offer.inUse > 0 || offer.destroySent {
		offer.mu.Unlock()
		return
	}
	offer.destroySent = true
	offer.mu.Unlock()

	cliente.dropHandler(offer.id)
	cliente.mu.Lock()
	delete(cliente.offers, offer.id)
	cliente.mu.Unlock()
	_ = cliente.conn.send(offer.id, dcOfferReqDestroy, nil, nil)
}

func (cliente *wlClient) receive(offerID uint32, mime string) ([]byte, error) {
	var fds [2]int
	if err := syscall.Pipe2(fds[:], syscall.O_CLOEXEC); err != nil {
		return nil, fmt.Errorf("crear pipe: %w", err)
	}
	// Lectura no bloqueante para poder usar deadlines con el poller de Go.
	_ = syscall.SetNonblock(fds[0], true)

	enc := &wlEncoder{}
	enc.str(mime)
	if err := cliente.conn.send(offerID, dcOfferReqReceive, enc.buf, []int{fds[1]}); err != nil {
		_ = syscall.Close(fds[0])
		_ = syscall.Close(fds[1])
		return nil, err
	}
	_ = syscall.Close(fds[1])

	archivo := os.NewFile(uintptr(fds[0]), "wl-clipboard-read")
	if archivo == nil {
		_ = syscall.Close(fds[0])
		return nil, errors.New("no se pudo abrir el pipe del portapapeles")
	}
	defer archivo.Close()
	_ = archivo.SetReadDeadline(time.Now().Add(clipCmdTimeout))

	data, err := io.ReadAll(io.LimitReader(archivo, clipMaxEntryBytes+1))
	if err != nil {
		if errors.Is(err, os.ErrDeadlineExceeded) {
			return nil, errors.New("tiempo de espera agotado leyendo el portapapeles")
		}
		return nil, err
	}
	if len(data) > clipMaxEntryBytes {
		return nil, fmt.Errorf("contenido del portapapeles demasiado grande (>%d MiB)", clipMaxEntryBytes>>20)
	}
	return data, nil
}

// serveSource atiende una petición de pegado escribiendo los datos en el pipe
// que entrega el compositor.
func serveSource(fd int, data []byte) {
	_ = syscall.SetNonblock(fd, true)
	archivo := os.NewFile(uintptr(fd), "wl-clipboard-send")
	if archivo == nil {
		_ = syscall.Close(fd)
		return
	}
	defer archivo.Close()
	_ = archivo.SetWriteDeadline(time.Now().Add(clipCmdTimeout))
	for len(data) > 0 {
		n, err := archivo.Write(data)
		if n > 0 {
			data = data[n:]
		}
		if err != nil {
			return
		}
	}
}

func (cliente *wlClient) clearSource(src *wlSource) {
	cliente.mu.Lock()
	if cliente.source == src {
		cliente.source = nil
	}
	cliente.mu.Unlock()
	cliente.dropHandler(src.id)
	_ = cliente.conn.send(src.id, dcSourceReqDestroy, nil, nil)
}

// ── utilidades ──────────────────────────────────────────────────

func (cliente *wlClient) allocID() uint32 {
	cliente.mu.Lock()
	defer cliente.mu.Unlock()
	id := cliente.nextID
	cliente.nextID++
	return id
}

func (cliente *wlClient) setHandler(id uint32, h wlHandler) {
	cliente.mu.Lock()
	cliente.handlers[id] = h
	cliente.mu.Unlock()
}

func (cliente *wlClient) getHandler(id uint32) wlHandler {
	cliente.mu.Lock()
	defer cliente.mu.Unlock()
	return cliente.handlers[id]
}

func (cliente *wlClient) dropHandler(id uint32) {
	cliente.mu.Lock()
	delete(cliente.handlers, id)
	cliente.mu.Unlock()
}

func (cliente *wlClient) snapshotGlobals() []wlGlobal {
	cliente.mu.Lock()
	defer cliente.mu.Unlock()
	out := make([]wlGlobal, 0, len(cliente.globals))
	for _, g := range cliente.globals {
		out = append(out, g)
	}
	return out
}

func (cliente *wlClient) pushFDs(fds []int) {
	if len(fds) == 0 {
		return
	}
	cliente.fdMu.Lock()
	cliente.pendingFDs = append(cliente.pendingFDs, fds...)
	cliente.fdMu.Unlock()
}

func (cliente *wlClient) popFD() int {
	cliente.fdMu.Lock()
	defer cliente.fdMu.Unlock()
	if len(cliente.pendingFDs) == 0 {
		return -1
	}
	fd := cliente.pendingFDs[0]
	cliente.pendingFDs = cliente.pendingFDs[1:]
	return fd
}

func (cliente *wlClient) fail(err error) {
	cliente.closeOnce.Do(func() {
		cliente.mu.Lock()
		if cliente.err == nil {
			cliente.err = err
		}
		cliente.mu.Unlock()

		close(cliente.done)
		_ = cliente.conn.conn.Close()

		cliente.fdMu.Lock()
		for _, fd := range cliente.pendingFDs {
			_ = syscall.Close(fd)
		}
		cliente.pendingFDs = nil
		cliente.fdMu.Unlock()
	})
}

func parseOOB(oob []byte) ([]int, error) {
	msgs, err := syscall.ParseSocketControlMessage(oob)
	if err != nil {
		return nil, err
	}
	var fds []int
	for i := range msgs {
		if msgs[i].Header.Level != syscall.SOL_SOCKET || msgs[i].Header.Type != syscall.SCM_RIGHTS {
			continue
		}
		rights, err := syscall.ParseUnixRights(&msgs[i])
		if err != nil {
			return nil, err
		}
		fds = append(fds, rights...)
	}
	return fds, nil
}

// chooseMime elige el mejor tipo ofrecido: texto primero y, si no hay, imagen.
func chooseMime(mimes []string) string {
	textPrefs := []string{"text/plain;charset=utf-8", "text/plain", "utf8_string", "string", "text"}
	for _, want := range textPrefs {
		for _, m := range mimes {
			if strings.EqualFold(m, want) {
				return m
			}
		}
	}
	imagePrefs := []string{"image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp"}
	for _, want := range imagePrefs {
		for _, m := range mimes {
			if strings.EqualFold(m, want) {
				return m
			}
		}
	}
	return ""
}

// mimesFor devuelve los tipos que ofrecerá una fuente. Para texto plano se
// añaden los alias clásicos (UTF8_STRING, STRING...) para que cualquier
// cliente pueda pegarlo; otros tipos se ofrecen tal cual.
func mimesFor(mime string) []string {
	m := strings.ToLower(mime)
	plain := strings.HasPrefix(m, "text/plain") || m == "utf8_string" || m == "string" || m == "text"
	if !plain {
		return []string{mime}
	}
	candidates := []string{"text/plain;charset=utf-8", "text/plain", "UTF8_STRING", "STRING", "TEXT"}
	out := make([]string, 0, len(candidates)+1)
	seen := make(map[string]bool, len(candidates)+1)
	add := func(m string) {
		key := strings.ToLower(m)
		if m == "" || seen[key] {
			return
		}
		seen[key] = true
		out = append(out, m)
	}
	add(mime)
	for _, m := range candidates {
		add(m)
	}
	return out
}
