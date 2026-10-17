#!/usr/bin/env python3
"""wallpaper-scan.py — color representativo de cada fondo, con caché incremental.

Calcula un tono dominante por fondo (imágenes y vídeos) para que el selector
de la shell pueda filtrar por color. El trabajo caro (decode + reducción a
HSV + clasificación) solo se hace para ficheros nuevos o modificados; el
resto se reutiliza de la caché JSON, así que abrir el selector no re-decoda
todos los fondos cada vez.

Uso:
    wallpaper-scan.py --cache <cache.json> --dir <carpeta> \
        [--image-exts jpg,jpeg,...] [--video-exts mp4,webm,...]

Salida (cache.json):
    {
      "version": 1,
      "files": {
        "/ruta/fondo.jpg": {
          "mtime": 1699999999.0,
          "size": 1234567,
          "tone": "blue",
          "hex": "#2a3f8f",
          "luma": 0.31
        }
      }
    }

`tone` es uno de: red orange yellow green cyan blue purple pink brown white
gray black. La lista debe coincidir con `WallpaperColorService.tones`
(Core/Services/WallpaperColorService.qml) y con los swatches de
`WallpaperFilterBar.qml`.

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

# Muestreo: 48x48 = 2304 px es de sobra para el tono dominante y barato de
# decodificar (los fondos de 4K bajan a esto en un solo paso).
SAMPLE = 48

# ---- umbrales de clasificación (documentados para poder ajustarlos) --------
# Un píxel "cuenta" como color si tiene saturación/valor mínimos.
SAT_MIN = 0.18
VAL_MIN = 0.12
# Un fondo solo se clasifica por tono si hay suficiente color en él... 
SAT_FRACTION = 0.20
# ...y ese tono cubre una parte real del área (si no, es ruido → acromático).
DOM_FRACTION = 0.12
# Cortes de luminancia para el eje acromático.
LUM_BLACK = 0.17
LUM_WHITE = 0.83


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


def image_rgb(path, magick):
    if not magick:
        return None
    # rgb:- emite 3 bytes/píxel crudos, sin parsear texto de ImageMagick.
    # jpeg:size hace que libjpeg decodifique a escala reducida (DCT scaling):
    # en fondos JPEG de 4K recorta el decode de forma notable. Inocuo en otros.
    return run_bytes([magick, "-define", f"jpeg:size={SAMPLE}x{SAMPLE}", path, "-resize",
                      f"{SAMPLE}x{SAMPLE}!", "-alpha", "off", "-depth", "8", "rgb:-"])


def video_rgb(path, ffmpeg):
    if not ffmpeg:
        return None
    vf = f"scale={SAMPLE}:{SAMPLE},setsar=1"
    size = SAMPLE * SAMPLE * 3
    # -ss 1 como todos los fondos (mismo patrón que extract-wallpaper-frame.sh);
    # los vídeos muy cortos caen al segundo 0.
    for ss in ("1", "0"):
        data = run_bytes([ffmpeg, "-v", "error", "-ss", ss, "-i", path, "-frames:v", "1", "-vf", vf,
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
        if data and len(data) >= size:
            return data[:size]
    return None


def hue_sector(hue):
    """Sector de hue (grados) para el histograma por área."""
    if hue >= 345 or hue < 15:
        return "red"
    if hue < 45:
        return "orange"
    if hue < 70:
        return "yellow"
    if hue < 165:
        return "green"
    if hue < 195:
        return "cyan"
    if hue < 255:
        return "blue"
    if hue < 290:
        return "purple"
    return "pink"


def refine_tone(sector, sat, val):
    """Ajusta el sector con el color medio del cubo (no píxel a píxel: en la
    frontera cada píxel salta de nombre, el cubo no). El marrón es un cálido
    oscuro y el rosa un rojo claro y suave, no hues propios."""
    if sector in ("orange", "yellow") and val < 0.5:
        return "brown"
    if sector == "red":
        if val < 0.45 and sat >= 0.35:
            return "brown"
        if sat < 0.45 and val > 0.6:
            return "pink"
    return sector


def to_hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(channel * 255))) for channel in rgb)


def classify(data):
    """rgb24 crudo → (tone, hex, luma). None si el búfer está incompleto."""
    count = SAMPLE * SAMPLE
    if not data or len(data) < count * 3:
        return None

    sum_r = sum_g = sum_b = 0.0
    buckets = {}  # sector -> [n, sum_r, sum_g, sum_b]
    saturated = 0
    for i in range(count):
        r = data[i * 3] / 255.0
        g = data[i * 3 + 1] / 255.0
        b = data[i * 3 + 2] / 255.0
        sum_r += r
        sum_g += g
        sum_b += b
        hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
        if sat >= SAT_MIN and val >= VAL_MIN:
            saturated += 1
            sector = hue_sector(hue * 360.0)
            acc = buckets.get(sector)
            if acc is None:
                buckets[sector] = [1, r, g, b]
            else:
                acc[0] += 1
                acc[1] += r
                acc[2] += g
                acc[3] += b

    avg = (sum_r / count, sum_g / count, sum_b / count)
    luma = 0.2126 * avg[0] + 0.7152 * avg[1] + 0.0722 * avg[2]

    tone = None
    rgb = avg
    if buckets:
        sector, acc = max(buckets.items(), key=lambda item: item[1][0])
        # El tono debe pesar sobre el total, no solo ganar entre los pocos
        # píxeles saturados: un fondo casi gris con un logo mini no es "azul".
        if saturated / count >= SAT_FRACTION and acc[0] / count >= DOM_FRACTION:
            mean = (acc[1] / acc[0], acc[2] / acc[0], acc[3] / acc[0])
            _, mean_sat, mean_val = colorsys.rgb_to_hsv(*mean)
            tone = refine_tone(sector, mean_sat, mean_val)
            # Color del swatch = media de ESE tono (más vivo que la media global).
            rgb = mean
    if tone is None:
        if luma < LUM_BLACK:
            tone = "black"
        elif luma > LUM_WHITE:
            tone = "white"
        else:
            tone = "gray"

    return tone, to_hex(rgb), round(luma, 4)


def matches_ext(name, exts):
    ext = os.path.splitext(name)[1].lstrip(".").lower()
    return ext in exts


def read_cache(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict) and isinstance(data.get("files"), dict):
            return data["files"]
    except (OSError, ValueError):
        pass
    return {}


def write_cache(path, files):
    tmp = path + ".tmp.%d" % os.getpid()
    payload = {"version": 1, "files": files}
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
    parser = argparse.ArgumentParser(description="Color dominante por fondo (caché incremental).")
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

        data = video_rgb(path, ffmpeg) if is_video else image_rgb(path, magick)
        result = classify(data)
        if result is None:
            failed += 1
            continue
        tone, hex_color, luma = result
        files[path] = {"mtime": stat.st_mtime, "size": stat.st_size, "tone": tone, "hex": hex_color,
                       "luma": luma}
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
