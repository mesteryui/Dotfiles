#!/usr/bin/env python3
"""wallpaper-scan.py — color representativo de cada fondo, con caché incremental.

Saca un par (hue, saturación) del color MEDIO de cada fondo (imágenes y
vídeos), al estilo de Ryoku: se reduce la imagen a 1x1 y se lee su HSL. El
selector de la shell agrupa ese par en 12 grupos de hue + neutro
(Core/Services/WallpaperColorService.qml) y filtra por grupo.

El trabajo caro (decode + media) solo se hace para ficheros nuevos o
modificados; el resto se reutiliza de la caché JSON, así que abrir el
selector no re-decoda todos los fondos cada vez.

Uso:
    wallpaper-scan.py --cache <cache.json> --dir <carpeta> \
        [--image-exts jpg,jpeg,...] [--video-exts mp4,webm,...]

Salida (cache.json):
    {
      "version": 2,
      "files": {
        "/ruta/fondo.jpg": {
          "mtime": 1699999999.0,
          "size": 1234567,
          "hue": 210.5,
          "sat": 42.0
        }
      }
    }

`hue` son grados (0-360) y `sat` el porcentaje (0-100) de saturación HSL. La
agrupación (bucket) vive en WallpaperColorService.qml, igual que en Ryoku
(index.sh emite hue/sat y el singleton los agrupa en un grupo de color).

Herramientas: ImageMagick (`magick` o `convert`) para imágenes y `ffmpeg`
para vídeos. Si falta la herramienta o falla el decode, ese fichero se omite
del mapa de colores (el fondo sigue listándose en el selector, pero no casa
con ningún color). Nunca aborta el escaneo completo por un fichero roto.

Sale 0 si la caché queda escrita o ya estaba vigente, 2 si la invocación es
incorrecta o no se puede leer/escribir la caché.
"""

import argparse
import colorsys
import json
import os
import shutil
import subprocess
import sys

# Muestreo para vídeos: un frame reducido a 48x48; su media es el color medio.
SAMPLE = 48

# v2: hue/sat (media HSL). v1 guardaba `tone`/`hex`/`luma` (histograma por
# píxel); una caché v1 se descarta y se recalcula.
CACHE_VERSION = 2


def which(*names):
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return None


def run_bytes(cmd):
    """Ejecuta y devuelve stdout crudo, o None si falla/timeout."""
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout


def parse_hue_sat(data):
    """stdout de magick con '%[fx:u.r*360] %[fx:u.g*100]' -> (hue, sat)."""
    if not data:
        return None
    try:
        parts = data.decode("ascii", "ignore").split()
        if len(parts) < 2:
            return None
        return (float(parts[0]), float(parts[1]))
    except ValueError:
        return None


def image_hue_sat(path, magick):
    if not magick:
        return None
    # Igual que Ryoku: media a 1x1 en sRGB y lectura HSL (u.r = hue, u.g = sat).
    # `jpeg:size` hace que libjpeg decodifique a escala reducida (DCT scaling):
    # en JPEG de 4K recorta el decode de forma notable. Inocuo en otros formatos.
    return parse_hue_sat(run_bytes([magick, "-define", f"jpeg:size={SAMPLE}x{SAMPLE}", path, "-alpha",
                                    "off", "-resize", "1x1!", "-colorspace", "HSL", "-format",
                                    "%[fx:u.r*360] %[fx:u.g*100]", "info:"]))


def video_hue_sat(path, ffmpeg):
    if not ffmpeg:
        return None
    vf = f"scale={SAMPLE}:{SAMPLE},setsar=1"
    size = SAMPLE * SAMPLE * 3
    # -ss 1 como todos los fondos (mismo patrón que extract-wallpaper-frame.sh);
    # los vídeos muy cortos caen al segundo 0.
    data = None
    for ss in ("1", "0"):
        data = run_bytes([ffmpeg, "-v", "error", "-ss", ss, "-i", path, "-frames:v", "1", "-vf", vf,
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
        if data and len(data) >= size:
            data = data[:size]
            break
        data = None
    if data is None:
        return None
    count = SAMPLE * SAMPLE
    sum_r = sum_g = sum_b = 0
    for i in range(count):
        sum_r += data[i * 3]
        sum_g += data[i * 3 + 1]
        sum_b += data[i * 3 + 2]
    r = sum_r / count / 255.0
    g = sum_g / count / 255.0
    b = sum_b / count / 255.0
    # hsl (h, l, s): nos quedamos con h (0-1) y s (0-1).
    hue, _, sat = colorsys.rgb_to_hls(r, g, b)
    return (hue * 360.0, sat * 100.0)


def matches_ext(name, exts):
    ext = os.path.splitext(name)[1].lstrip(".").lower()
    return ext in exts


def read_cache(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict) and data.get("version") == CACHE_VERSION and isinstance(data.get(
                "files"), dict):
            return data["files"]
    except (OSError, ValueError):
        pass
    return {}


def write_cache(path, files):
    tmp = path + ".tmp.%d" % os.getpid()
    payload = {"version": CACHE_VERSION, "files": files}
    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, sort_keys=True, indent=0)
            handle.write("\n")
        os.replace(tmp, path)
    except OSError as err:
        print("no se pudo escribir la caché: %s" % err, file=sys.stderr)
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False
    return True


def main(argv):
    parser = argparse.ArgumentParser(description="Color medio (hue/sat) por fondo, con caché incremental.")
    parser.add_argument("--cache", required=True, help="ruta del JSON de caché")
    parser.add_argument("--dir", required=True, help="carpeta de fondos")
    parser.add_argument("--image-exts", default="jpg,jpeg,png,webp,avif,bmp,svg")
    parser.add_argument("--video-exts", default="mp4,webm,mov,mkv,ogv,m4v")
    args = parser.parse_args(argv)

    if not os.path.isdir(args.dir):
        print("no existe la carpeta: %s" % args.dir, file=sys.stderr)
        return 2

    images = {e.strip().lower() for e in args.image_exts.split(",") if e.strip()}
    videos = {e.strip().lower() for e in args.video_exts.split(",") if e.strip()}

    magick = which("magick", "convert")
    ffmpeg = which("ffmpeg")

    cached = read_cache(args.cache)
    files = {}
    computed = 0
    reused = 0
    failed = 0

    try:
        entries = sorted(os.listdir(args.dir))
    except OSError as err:
        print("no se pudo listar la carpeta: %s" % err, file=sys.stderr)
        return 2

    for name in entries:
        path = os.path.join(args.dir, name)
        if not os.path.isfile(path):
            continue
        is_video = matches_ext(name, videos)
        if not is_video and not matches_ext(name, images):
            continue

        try:
            stat = os.stat(path)
        except OSError:
            continue

        prev = cached.get(path)
        if prev and prev.get("mtime") == stat.st_mtime and prev.get("size") == stat.st_size:
            files[path] = prev
            reused += 1
            continue

        pair = video_hue_sat(path, ffmpeg) if is_video else image_hue_sat(path, magick)
        if pair is None:
            failed += 1
            continue
        hue, sat = pair
        files[path] = {
            "mtime": stat.st_mtime,
            "size": stat.st_size,
            "hue": round(hue, 2),
            "sat": round(sat, 2)
        }
        computed += 1

    # Sin cambios reales no se reescribe: evita despertar el watcher del
    # FileView (y el rebind de la UI) en cada apertura del selector.
    if computed > 0 or set(files) != set(cached):
        if not write_cache(args.cache, files):
            return 2

    print("wallpaper-scan: %d fondos (%d nuevos, %d reusados, %d sin color)" % (len(files), computed,
                                                                                reused, failed))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
