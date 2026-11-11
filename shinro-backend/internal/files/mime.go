// Detección del tipo de archivo al estilo del sistema operativo (`file`).
//
// Orden de resolución:
//  1. Firma del contenido (magic bytes): es la fuente principal y detecta el
//     formato real aunque la extensión mienta o no exista. Se combinan las
//     firmas de net/http con una tabla propia para ELF, PE, Mach-O, tar,
//     xz, zstd, 7z, sqlite, OLE, RPM, FLAC, EBML, MP3 sin ID3...
//  2. Extensión (mime.TypeByExtension, tabla MIME del sistema): refina el
//     tipo en contenedores genéricos (docx/epub/odt son ZIP, .deb es ar,
//     .doc es OLE) y aporta MIME más concretos para texto (JSON, YAML...).
//  3. El MIME final se traduce a una categoría (`kind`) que Quickshell usa
//     para decidir el preview: imagen, texto, audio, vídeo, PDF, documento,
//     comprimido, ejecutable, fuente, binario u otro.
//
// El contenido manda: un .txt que en realidad es un PNG se clasifica como
// imagen, y un .txt con bytes binarios no se muestra como texto.
package files

import (
	"bytes"
	"encoding/binary"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// Categorías de preview que consume Quickshell.
const (
	KindImage      = "image"      // mostrar la imagen directamente
	KindText       = "text"       // leer una cabecera y pintarla como texto
	KindAudio      = "audio"      // carátula / metadatos
	KindVideo      = "video"      // fotograma
	KindPDF        = "pdf"        // primera página
	KindDocument   = "document"   // ofimática/ebook: sin preview por ahora
	KindArchive    = "archive"    // comprimido/paquete: sin preview
	KindExecutable = "executable" // binario ejecutable: sin preview
	KindFont       = "font"       // tipografía: sin preview
	KindBinary     = "binary"     // binario sin formato reconocido
	KindOther      = "other"      // desconocido
)

// sniffLen es lo que necesita net/http.DetectContentType y suficiente para
// las firmas propias (tar usa el offset 257).
const sniffLen = 512

// detectMime devuelve el MIME y la categoría de preview de un archivo.
func detectMime(path string, size int64) (string, string) {
	if size == 0 {
		return "inode/x-empty", KindOther
	}
	magic := magicMime(readHead(path, size))
	ext := normalizeExtMime(path, mime.TypeByExtension(strings.ToLower(filepath.Ext(path))))
	typ := resolveMime(magic, ext)
	return typ, kindForMime(typ)
}

// normalizeExtMime corrige colisiones de la tabla MIME del sistema. `.otf`
// es OpenType, pero mime.types lo asigna a la plantilla de fórmula de ODF.
func normalizeExtMime(path, typ string) string {
	if strings.EqualFold(filepath.Ext(path), ".otf") &&
		strings.HasPrefix(baseMime(typ), "application/vnd.oasis.opendocument.formula") {
		return "font/otf"
	}
	return typ
}

// readHead lee los primeros sniffLen bytes del archivo. Devuelve nil si no
// se puede abrir (permisos, carrera con un borrado...).
func readHead(path string, size int64) []byte {
	if size <= 0 {
		return nil
	}
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	buf := make([]byte, sniffLen)
	// Un archivo más corto devuelve io.ErrUnexpectedEOF con n > 0: sirve.
	n, _ := io.ReadFull(f, buf)
	return buf[:n]
}

// magicMime reconoce el formato por el contenido, como `file`.
func magicMime(head []byte) string {
	if len(head) == 0 {
		return ""
	}
	if typ := customMagic(head); typ != "" {
		return typ
	}
	return http.DetectContentType(head)
}

// customMagic cubre formatos que net/http no reconoce (o reconoce de forma
// demasiado genérica). El orden importa: las firmas más específicas primero.
func customMagic(h []byte) string {
	has := func(sig string) bool { return bytes.HasPrefix(h, []byte(sig)) }

	switch {
	case has("\x7fELF"):
		return elfMime(h)
	case len(h) >= 64 && h[0] == 'M' && h[1] == 'Z':
		return "application/vnd.microsoft.portable-executable"
	case has("\xfe\xed\xfa\xce"), has("\xce\xfa\xed\xfe"),
		has("\xfe\xed\xfa\xcf"), has("\xcf\xfa\xed\xfe"):
		return "application/x-mach-binary"
	case has("\xca\xfe\xba\xbe") && len(h) >= 8:
		// 0xCAFEBABE es tanto Java class como Mach-O universal.
		// En Java los 4 bytes siguientes son la versión (>= 45).
		if binary.BigEndian.Uint32(h[4:8]) >= 45 {
			return "application/java-vm"
		}
		return "application/x-mach-binary"
	case has("\x00asm"):
		return "application/wasm"
	case has("MSCF"):
		return "application/vnd.ms-cab-compressed"
	case has("SQLite format 3\x00"):
		return "application/vnd.sqlite3"
	case has("\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"):
		return "application/x-ole-storage" // .doc/.xls/.ppt/.msi
	case has("!<arch>\n"):
		return "application/x-archive" // .a/.deb/.ar
	case has("\xed\xab\xee\xdb"):
		return "application/x-rpm"
	case len(h) >= 262 && string(h[257:262]) == "ustar":
		return "application/x-tar"
	case has("\xfd7zXZ\x00"):
		return "application/x-xz"
	case has("\x28\xb5\x2f\xfd"):
		return "application/zstd"
	case has("7z\xbc\xaf\x27\x1c"):
		return "application/x-7z-compressed"
	case has("\x04\x22\x4d\x18"):
		return "application/x-lz4"
	case has("LZIP"):
		return "application/x-lzip"
	case has("\x1f\x9d"):
		return "application/x-compress"
	case has("BZh"):
		return "application/x-bzip2"
	case has("fLaC"):
		return "audio/flac"
	case has("\x1a\x45\xdf\xa3"): // EBML: WebM o Matroska
		if bytes.Contains(h, []byte("matroska")) {
			return "video/x-matroska"
		}
		return "video/webm"
	case has("{\\rtf"):
		return "application/rtf"
	case looksLikeMP3(h):
		return "audio/mpeg"
	}
	return ""
}

// elfMime distingue ejecutable, PIE, objeto y core leyendo e_type.
func elfMime(h []byte) string {
	if len(h) < 18 {
		return "application/x-elf"
	}
	var eType uint16
	if h[5] == 1 { // ELFDATA2LSB
		eType = binary.LittleEndian.Uint16(h[16:18])
	} else {
		eType = binary.BigEndian.Uint16(h[16:18])
	}
	switch eType {
	case 1:
		return "application/x-object"
	case 2:
		return "application/x-executable"
	case 3:
		return "application/x-pie-executable"
	case 4:
		return "application/x-coredump"
	}
	return "application/x-elf"
}

// looksLikeMP3 valida la cabecera de trama MPEG para no confundir binarios
// aleatorios que empiecen por 0xFF con audio.
func looksLikeMP3(h []byte) bool {
	if len(h) < 4 || h[0] != 0xFF || h[1]&0xE0 != 0xE0 {
		return false
	}
	version := (h[1] >> 3) & 0x3
	layer := (h[1] >> 1) & 0x3
	bitrate := (h[2] >> 4) & 0xF
	sample := (h[2] >> 2) & 0x3
	return version != 1 && layer != 0 && bitrate != 0xF && sample != 0x3
}

// resolveMime combina la firma del contenido con la extensión. La firma es
// la fuente principal; la extensión refina contenedores genéricos y tipos de
// texto, y sirve de pista cuando el contenido es un binario sin firma.
func resolveMime(magic, ext string) string {
	if magic == "" {
		return ext
	}
	if ext == "" {
		return magic
	}

	magicKind := kindForMime(magic)
	extKind := kindForMime(ext)

	// 1. Contenedores genéricos: la extensión identifica el formato real
	//    (docx/xlsx/odt/epub son ZIP; .deb es ar; .doc/.msi son OLE).
	if isGenericContainer(magic) &&
		(extKind == KindDocument || extKind == KindArchive ||
			extKind == KindExecutable || extKind == KindFont) {
		return ext
	}

	// 2. Texto por contenido: la extensión puede aportar un MIME más
	//    específico (JSON, YAML, código) o revelar una imagen (SVG).
	if magicKind == KindText {
		if extKind == KindText || extKind == KindImage {
			return ext
		}
		return magic
	}

	// 3. Binario sin firma conocida: la extensión es la única pista, pero no
	//    se acepta "texto" por extensión (el contenido manda).
	if magic == "application/octet-stream" {
		if extKind == KindText || extKind == KindOther {
			return magic
		}
		return ext
	}

	// 4. Firma concreta: manda el contenido aunque la extensión diga otra cosa.
	return magic
}

// baseMime quita parámetros (`; charset=...`) y normaliza a minúsculas.
func baseMime(typ string) string {
	if i := strings.IndexByte(typ, ';'); i >= 0 {
		typ = typ[:i]
	}
	return strings.ToLower(strings.TrimSpace(typ))
}

// isGenericContainer indica que la firma es un contenedor cuyo formato
// concreto solo se puede saber por la extensión.
func isGenericContainer(typ string) bool {
	switch baseMime(typ) {
	case "application/zip", "application/gzip", "application/x-gzip",
		"application/x-bzip2", "application/x-xz", "application/zstd",
		"application/x-7z-compressed", "application/x-rar-compressed",
		"application/vnd.rar", "application/x-tar", "application/x-archive",
		"application/x-ole-storage", "application/x-cpio",
		"application/x-compress", "application/x-lzip", "application/x-lz4":
		return true
	}
	return false
}

// kindForMime traduce un MIME a la categoría de preview.
func kindForMime(typ string) string {
	m := baseMime(typ)
	if m == "" {
		return KindOther
	}
	switch {
	case strings.HasPrefix(m, "image/"):
		return KindImage
	case strings.HasPrefix(m, "text/"):
		return KindText
	case strings.HasPrefix(m, "audio/"):
		return KindAudio
	case strings.HasPrefix(m, "video/"):
		return KindVideo
	case strings.HasPrefix(m, "font/"):
		return KindFont
	case m == "application/pdf":
		return KindPDF
	case m == "application/ogg", m == "application/x-ogg":
		return KindAudio
	case m == "application/vnd.ms-fontobject":
		return KindFont
	case isTextApplication(m):
		return KindText
	case isDocumentMime(m):
		return KindDocument
	case isArchiveMime(m):
		return KindArchive
	case isExecutableMime(m):
		return KindExecutable
	}
	return KindBinary
}

// isTextApplication reconoce tipos application/* que son texto legible.
func isTextApplication(m string) bool {
	if strings.HasSuffix(m, "+json") || strings.HasSuffix(m, "+xml") || strings.HasSuffix(m, "+yaml") {
		return true
	}
	switch m {
	case "application/json", "application/xml", "application/yaml",
		"application/x-yaml", "application/toml", "application/x-toml",
		"application/sql", "application/x-ndjson",
		"application/javascript", "application/x-javascript", "application/ecmascript",
		"application/x-desktop", "application/x-wine-extension-ini",
		"application/x-sh", "application/x-shellscript", "application/x-httpd-php",
		"application/x-php", "application/x-perl", "application/x-python",
		"application/x-ruby", "application/x-lua", "application/x-awk",
		"application/x-tex", "application/x-latex", "application/x-subrip",
		"application/x-makefile", "application/x-nfo":
		return true
	}
	return false
}

// isDocumentMime reconoce ofimática, ebooks y documentos con contenedor
// propio. No tienen preview todavía, pero se distinguen de un binario opaco.
func isDocumentMime(m string) bool {
	if strings.HasPrefix(m, "application/vnd.openxmlformats-officedocument.") ||
		strings.HasPrefix(m, "application/vnd.oasis.opendocument.") ||
		(strings.HasPrefix(m, "application/vnd.ms-") &&
			m != "application/vnd.ms-cab-compressed" &&
			m != "application/vnd.ms-fontobject") {
		return true
	}
	switch m {
	case "application/msword", "application/rtf", "application/epub+zip",
		"application/vnd.amazon.ebook", "application/x-mobipocket-ebook",
		"application/x-abiword", "application/vnd.comicbook+zip",
		"application/vnd.comicbook-rar", "application/vnd.wordperfect",
		"application/x-fictionbook+xml":
		return true
	}
	return false
}

// isArchiveMime reconoce comprimidos, paquetes e imágenes de disco.
func isArchiveMime(m string) bool {
	switch m {
	case "application/zip", "application/gzip", "application/x-gzip",
		"application/x-bzip2", "application/x-xz", "application/zstd",
		"application/x-zstd", "application/x-7z-compressed",
		"application/x-rar-compressed", "application/vnd.rar",
		"application/x-tar", "application/x-gtar", "application/x-compressed-tar",
		"application/x-archive", "application/x-cpio",
		"application/x-compress", "application/x-lzip", "application/x-lz4",
		"application/vnd.debian.binary-package", "application/x-rpm",
		"application/x-msi", "application/vnd.ms-cab-compressed",
		"application/x-iso9660-image", "application/vnd.efi.iso",
		"application/vnd.efi.img", "application/x-apple-diskimage",
		"application/java-archive", "application/vnd.android.package-archive",
		"application/x-xar":
		return true
	}
	return false
}

// isExecutableMime reconoce binarios ejecutables y objetos.
func isExecutableMime(m string) bool {
	switch m {
	case "application/x-elf", "application/x-executable",
		"application/x-pie-executable", "application/x-sharedlib",
		"application/x-mach-binary", "application/x-dosexec",
		"application/vnd.microsoft.portable-executable",
		"application/x-msdownload", "application/wasm",
		"application/java-vm", "application/x-java-applet":
		return true
	}
	return false
}

// newResult construye un Result con el MIME y la categoría ya resueltos.
// Se llama desde el walker (en paralelo): el coste es abrir y leer 512 bytes
// por resultado, igual que hace `file`.
func newResult(path, name string, size int64) *Result {
	typ, kind := detectMime(path, size)
	return &Result{
		Path: path,
		Name: name,
		Size: size,
		Mime: typ,
		Kind: kind,
	}
}
