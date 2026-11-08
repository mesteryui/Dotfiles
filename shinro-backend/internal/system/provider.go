// Package system provee métricas del sistema leyendo /proc y /sys directamente.
// No depende de ningún otro paquete del backend.
package system

import (
	"bufio"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Stats contiene los recursos del sistema que emite el backend.
type Stats struct {
	RAMPercent     float64 `json:"ram_percent"`
	RAMUsedGB      float64 `json:"ram_used_gb"`
	RAMTotalGB     float64 `json:"ram_total_gb"`
	CPUPercent     float64 `json:"cpu_percent"`
	CPUCount       int     `json:"cpu_cores"`
	SwapPercent    float64 `json:"swap_percent"`
	SwapTotalMiB   float64 `json:"swap_total_mib"`
	SwapUsedMiB    float64 `json:"swap_used_mib"`
	DiskTotalBytes uint64  `json:"disk_total_bytes"`
	DiskUsedBytes  uint64  `json:"disk_used_bytes"`
	DiskPercent    float64 `json:"disk_percent"`
	UptimeSec      uint64  `json:"uptime_seconds"`
	TemperatureC   float64 `json:"temperature_c"`
	Hostname       string  `json:"hostname"`
}

type cpuTimes struct {
	user, nice, system, idle, iowait, irq, softirq, steal uint64
}

// Provider lee métricas del sistema. La primera llamada a CPU devuelve 0
// porque necesita dos lecturas para calcular el porcentaje.
type Provider struct {
	// mu serializa Stats: el cálculo de CPU depende de la lectura anterior
	// y varios clientes pueden pedir métricas a la vez.
	mu           sync.Mutex
	prevCPUTimes *cpuTimes
	prevTime     time.Time
}

// New crea un proveedor de sistema limpio.
func New() *Provider {
	return &Provider{}
}

// Stats devuelve una instantánea de CPU, RAM, swap, uptime y temperatura.
func (p *Provider) Stats() (Stats, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	var s Stats

	if err := p.memory(&s); err != nil {
		return s, err
	}
	if err := p.cpu(&s); err != nil {
		return s, err
	}
	if err := p.swap(&s); err != nil {
		return s, err
	}
	if err := p.uptime(&s); err != nil {
		return s, err
	}
	// La temperatura no es crítica: si falla, dejamos -1.
	if err := p.temperature(&s); err != nil {
		s.TemperatureC = -1
	}
	// El disco tampoco es crítico: si falla, queda a cero.
	_ = p.disk(&s)

	s.CPUCount = runtime.NumCPU()
	s.Hostname = p.hostname()

	return s, nil
}

func (p *Provider) memory(s *Stats) error {
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return err
	}
	defer f.Close()

	var memTotal, memAvailable uint64
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		switch {
		case strings.HasPrefix(line, "MemTotal:"):
			memTotal = parseKb(line)
		case strings.HasPrefix(line, "MemAvailable:"):
			memAvailable = parseKb(line)
		}
	}
	if memTotal == 0 {
		return nil
	}

	s.RAMTotalGB = float64(memTotal) / 1024 / 1024
	used := memTotal - memAvailable
	s.RAMUsedGB = float64(used) / 1024 / 1024
	s.RAMPercent = float64(used) / float64(memTotal) * 100
	return nil
}

func parseKb(line string) uint64 {
	fields := strings.Fields(line)
	if len(fields) < 2 {
		return 0
	}
	v, _ := strconv.ParseUint(fields[1], 10, 64)
	return v
}

func (p *Provider) cpu(s *Stats) error {
	f, err := os.Open("/proc/stat")
	if err != nil {
		return err
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	if !sc.Scan() {
		return nil
	}
	line := sc.Text()
	if !strings.HasPrefix(line, "cpu ") {
		return nil
	}
	fields := strings.Fields(line)
	if len(fields) < 8 {
		return nil
	}

	cur := cpuTimes{}
	cur.user, _ = strconv.ParseUint(fields[1], 10, 64)
	cur.nice, _ = strconv.ParseUint(fields[2], 10, 64)
	cur.system, _ = strconv.ParseUint(fields[3], 10, 64)
	cur.idle, _ = strconv.ParseUint(fields[4], 10, 64)
	cur.iowait, _ = strconv.ParseUint(fields[5], 10, 64)
	cur.irq, _ = strconv.ParseUint(fields[6], 10, 64)
	cur.softirq, _ = strconv.ParseUint(fields[7], 10, 64)
	if len(fields) > 8 {
		cur.steal, _ = strconv.ParseUint(fields[8], 10, 64)
	}

	now := time.Now()
	if p.prevCPUTimes != nil {
		prevIdle := p.prevCPUTimes.idle + p.prevCPUTimes.iowait
		curIdle := cur.idle + cur.iowait
		prevTotal := p.prevCPUTimes.user + p.prevCPUTimes.nice + p.prevCPUTimes.system +
			p.prevCPUTimes.idle + p.prevCPUTimes.iowait + p.prevCPUTimes.irq +
			p.prevCPUTimes.softirq + p.prevCPUTimes.steal
		curTotal := cur.user + cur.nice + cur.system + cur.idle + cur.iowait +
			cur.irq + cur.softirq + cur.steal

		if curTotal > prevTotal {
			s.CPUPercent = float64(curTotal-prevTotal-(curIdle-prevIdle)) / float64(curTotal-prevTotal) * 100
		}
	}
	p.prevCPUTimes = &cur
	p.prevTime = now
	return nil
}

func (p *Provider) swap(s *Stats) error {
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return err
	}
	defer f.Close()

	var swapTotal, swapFree uint64
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		switch {
		case strings.HasPrefix(line, "SwapTotal:"):
			swapTotal = parseKb(line)
		case strings.HasPrefix(line, "SwapFree:"):
			swapFree = parseKb(line)
		}
	}
	s.SwapTotalMiB = float64(swapTotal) / 1024
	if swapTotal == 0 {
		s.SwapPercent = 0
		s.SwapUsedMiB = 0
		return nil
	}
	used := swapTotal - swapFree
	s.SwapUsedMiB = float64(used) / 1024
	s.SwapPercent = float64(used) / float64(swapTotal) * 100
	return nil
}

// disk devuelve el uso del sistema de archivos raíz.
func (p *Provider) disk(s *Stats) error {
	var st syscall.Statfs_t
	if err := syscall.Statfs("/", &st); err != nil {
		return err
	}
	bsize := uint64(st.Bsize)
	total := st.Blocks * bsize
	// Bavail descuenta el espacio reservado para root, igual que `df`.
	free := st.Bavail * bsize
	if total == 0 {
		return nil
	}
	used := total - free
	s.DiskTotalBytes = total
	s.DiskUsedBytes = used
	s.DiskPercent = float64(used) / float64(total) * 100
	return nil
}

func (p *Provider) uptime(s *Stats) error {
	f, err := os.Open("/proc/uptime")
	if err != nil {
		return err
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	if !sc.Scan() {
		return nil
	}
	fields := strings.Fields(sc.Text())
	if len(fields) == 0 {
		return nil
	}
	secs, err := strconv.ParseFloat(fields[0], 64)
	if err != nil {
		return nil
	}
	s.UptimeSec = uint64(secs)
	return nil
}

func (p *Provider) hostname() string {
	// Leer /proc/sys/kernel/hostname primero (más directo)
	data, err := os.ReadFile("/proc/sys/kernel/hostname")
	if err == nil {
		return strings.TrimSpace(string(data))
	}
	// Fallback a os.Hostname()
	h, err := os.Hostname()
	if err == nil {
		return h
	}
	return "localhost"
}

func (p *Provider) temperature(s *Stats) error {
	// Busca la primera zona térmica disponible en /sys/class/thermal
	entries, err := os.ReadDir("/sys/class/thermal")
	if err != nil {
		return err
	}
	for _, e := range entries {
		name := e.Name()
		if !strings.HasPrefix(name, "thermal_zone") {
			continue
		}
		tempPath := "/sys/class/thermal/" + name + "/temp"
		data, err := os.ReadFile(tempPath)
		if err != nil {
			continue
		}
		val, err := strconv.ParseFloat(strings.TrimSpace(string(data)), 64)
		if err != nil {
			continue
		}
		// El archivo está en milésimas de grado Celsius.
		s.TemperatureC = val / 1000
		return nil
	}
	return os.ErrNotExist
}
