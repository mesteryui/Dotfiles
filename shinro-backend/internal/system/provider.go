// Package system provee métricas del sistema leyendo /proc y /sys directamente.
// No depende de ningún otro paquete del backend.
package system

import (
	"bufio"
	"os"
	"path/filepath"
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

	// Batería (leída de /sys/class/power_supply). En equipos sin batería
	// BatteryPercent vale -1 y BatteryStatus está vacío.
	BatteryPercent     float64 `json:"battery_percent"`
	BatteryStatus      string  `json:"battery_status"`
	BatteryCharging    bool    `json:"battery_charging"`
	BatteryTimeToEmpty int     `json:"battery_time_to_empty_min"`
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
func (provider *Provider) Stats() (Stats, error) {
	provider.mu.Lock()
	defer provider.mu.Unlock()

	var s Stats

	if err := provider.memory(&s); err != nil {
		return s, err
	}
	if err := provider.cpu(&s); err != nil {
		return s, err
	}
	if err := provider.swap(&s); err != nil {
		return s, err
	}
	if err := provider.uptime(&s); err != nil {
		return s, err
	}
	// La temperatura no es crítica: si falla, dejamos -1.
	if err := provider.temperature(&s); err != nil {
		s.TemperatureC = -1
	}
	// La batería tampoco es crítica: si falla, dejamos los valores neutros.
	if err := provider.battery(&s); err != nil {
		s.BatteryPercent = -1
		s.BatteryStatus = ""
		s.BatteryCharging = false
		s.BatteryTimeToEmpty = -1
	}
	// El disco tampoco es crítico: si falla, queda a cero.
	_ = provider.disk(&s)

	s.CPUCount = runtime.NumCPU()
	s.Hostname = provider.hostname()

	return s, nil
}

func (provider *Provider) memory(s *Stats) error {
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

func (provider *Provider) cpu(s *Stats) error {
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
	if provider.prevCPUTimes != nil {
		prevIdle := provider.prevCPUTimes.idle + provider.prevCPUTimes.iowait
		curIdle := cur.idle + cur.iowait
		prevTotal := provider.prevCPUTimes.user + provider.prevCPUTimes.nice + provider.prevCPUTimes.system +
			provider.prevCPUTimes.idle + provider.prevCPUTimes.iowait + provider.prevCPUTimes.irq +
			provider.prevCPUTimes.softirq + provider.prevCPUTimes.steal
		curTotal := cur.user + cur.nice + cur.system + cur.idle + cur.iowait +
			cur.irq + cur.softirq + cur.steal

		if curTotal > prevTotal {
			s.CPUPercent = float64(curTotal-prevTotal-(curIdle-prevIdle)) / float64(curTotal-prevTotal) * 100
		}
	}
	provider.prevCPUTimes = &cur
	provider.prevTime = now
	return nil
}

func (provider *Provider) swap(s *Stats) error {
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
func (provider *Provider) disk(s *Stats) error {
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

func (provider *Provider) uptime(s *Stats) error {
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

func (provider *Provider) hostname() string {
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

func (provider *Provider) temperature(s *Stats) error {
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

// battery lee el estado de la batería desde /sys/class/power_supply.
//
// Todo se lee de pseudo-archivos del kernel: no hace falta lanzar procesos
// (acpi, upower) ni consultar nada por red, así que el coste por lectura es
// despreciable aunque el módulo se empuje cada pocos segundos.
//
// En equipos sin batería devuelve os.ErrNotExist y el llamante deja los
// valores neutros.
func (provider *Provider) battery(s *Stats) error {
	const base = "/sys/class/power_supply"

	entries, err := os.ReadDir(base)
	if err != nil {
		return err
	}

	for _, e := range entries {
		dir := filepath.Join(base, e.Name())

		// type == "Battery" identifica la batería (hay también "Mains",
		// "USB" y "Wireless" que no sirven).
		typ, err := os.ReadFile(filepath.Join(dir, "type"))
		if err != nil || strings.TrimSpace(string(typ)) != "Battery" {
			continue
		}

		s.BatteryStatus = readTrimmed(filepath.Join(dir, "status"))
		s.BatteryCharging = s.BatteryStatus == "Charging" || s.BatteryStatus == "Full"
		s.BatteryTimeToEmpty = -1

		if capacity := readInt(filepath.Join(dir, "capacity")); capacity >= 0 {
			s.BatteryPercent = float64(capacity)
		} else {
			// Sin "capacity", se calcula con energía/carga actual y total.
			now := readInt(filepath.Join(dir, "energy_now"))
			full := readInt(filepath.Join(dir, "energy_full"))
			if now > 0 && full > 0 {
				s.BatteryPercent = float64(now) / float64(full) * 100
			}
		}

		// Tiempo restante: energía/potencia (o carga/corriente).
		now := readInt(filepath.Join(dir, "energy_now"))
		power := readInt(filepath.Join(dir, "power_now"))
		if now <= 0 || power <= 0 {
			now = readInt(filepath.Join(dir, "charge_now"))
			power = readInt(filepath.Join(dir, "current_now"))
		}
		if now > 0 && power > 0 {
			// now en µWh y power en µW (o µAh y µA) → horas. Horas * 60 = minutos.
			s.BatteryTimeToEmpty = int((float64(now) / float64(power)) * 60)
		}

		return nil
	}

	return os.ErrNotExist
}

// readTrimmed lee un archivo de texto y elimina los espacios.
func readTrimmed(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// readInt lee un entero de un archivo; devuelve -1 si no se puede leer.
func readInt(path string) int64 {
	data, err := os.ReadFile(path)
	if err != nil {
		return -1
	}
	v, err := strconv.ParseInt(strings.TrimSpace(string(data)), 10, 64)
	if err != nil {
		return -1
	}
	return v
}
