#!/usr/bin/env bash
# check.sh — chequeo de calidad para la shell quickshell.
#
# Uso:
#   scripts/check.sh            # chequea (no modifica)
#   scripts/check.sh --fix      # además auto-formatea (qmlformat -i + conventions --fix)
#   scripts/check.sh --strict   # las convenciones propias también fallan (por defecto solo informan)
#
# Capas:
#   1. qmllint (Qt6): sintaxis QML. Falla si hay errores de sintaxis.
#   2. qmlformat (Qt6): formato según .qmlformat.ini. Falla si hay ficheros sucios.
#   3. qml-lint-conventions.py: orden Qt + separadores. Informa por defecto (el repo
#      aún tiene ~1000 avisos pendientes); con --strict falla.
#   4. JSON i18n: parse de Core/i18n/*.json. Falla si hay JSON roto.
#   5. JS: qmllint sobre Core/Services/*.js y Launcher/**/*.js (dialecto QML
#      con `.pragma library`, que node --check no entiende). Falla si rompe.
#   6. M3/robustez (grep): colores hardcodeados `color: "#..."`. Falla si aparecen.
#
# Nota Qt5/Qt6: /usr/bin/qmllint es Qt5 y aborta (exit 255) con
# `pragma ComponentBehavior: Bound`. Se usa siempre el binario Qt6.

set -u

# Ruta física (pwd -P): ~/.config/quickshell es un symlink y find(1) sin -L
# no desciende de un dir inicial symlinkeado (daría 0 ficheros).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIX=0
STRICT=0
for arg in "$@"; do
    case "$arg" in
        --fix) FIX=1 ;;
        --strict) STRICT=1 ;;
        -h|--help)
            sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        *) echo "flag desconocida: $arg (usa --fix, --strict)" >&2; exit 2 ;;
    esac
done

# --- binarios Qt6 primero -------------------------------------------------
pick_bin() {
    if [ -x "/usr/lib/qt6/bin/$1" ]; then
        echo "/usr/lib/qt6/bin/$1"
    elif command -v "$1" >/dev/null 2>&1; then
        command -v "$1"
    else
        echo ""
    fi
}
QMMLINT="$(pick_bin qmllint)"
QMLFORMAT="$(pick_bin qmlformat)"
if [ -z "$QMMLINT" ] || [ -z "$QMLFORMAT" ]; then
    echo "ERROR: qmllint/qmlformat no encontrados (instala qt6-declarative)" >&2
    exit 2
fi
if "$QMMLINT" --version 2>&1 | grep -q "^qmllint 1\.0"; then
    echo "AVISO: $QMMLINT es Qt5 (rompe con pragma ComponentBehavior); busca qt6." >&2
fi

PASS=0
FAIL=0
WARN=0
step() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok()   { PASS=$((PASS+1)); echo "  OK: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN+1)); echo "  AVISO: $1"; }

mapfile -d '' QML_FILES < <(find "$ROOT" -name '*.qml' -print0 | sort -z)
TOTAL_QML=${#QML_FILES[@]}
echo "Root: $ROOT ($TOTAL_QML QML)"
if [ "$TOTAL_QML" -eq 0 ]; then
    echo "ERROR: no se encontraron .qml bajo $ROOT" >&2
    exit 2
fi

# Excluidos de qmlformat (check y --fix): qmlformat ≤6.12 no es idempotente
# con template literals JS largos (parte `${...}` en varias líneas e inserta
# saltos reales dentro del string). Ocurrió en WeatherService.qml (URLs de
# open-meteo rotas). Se revisa a mano; qmllint sí lo cubre.
FMT_EXCLUDE=("Core/Services/WeatherService.qml")
FMT_FILES=()
for f in "${QML_FILES[@]}"; do
    skip=0
    for ex in "${FMT_EXCLUDE[@]}"; do
        [ "${f#"$ROOT"/}" = "$ex" ] && { skip=1; break; }
    done
    [ $skip -eq 0 ] && FMT_FILES+=("$f")
done

# Helper: qmllint fichero a fichero en paralelo.
# xargs(1) aborta TODO el lote si un fichero devuelve exit 255 (error de
# sintaxis) sin decir cuál (exit 124). Por eso se va de uno en uno: cada
# worker deja su log y solo imprime el fichero si falla.
# Uso: lint_many <dir_logs> <importdir|-> <ficheros...>
# Imprime la lista de ficheros con error (vacío si todo ok).
_lint_one() {
    local f="$1"
    local log="$LINT_TMP/${f//\//_}.log"
    local args=()
    if [ -n "${LINT_IMPORT_DIR:-}" ]; then args=(-I "$LINT_IMPORT_DIR" -I /usr/lib/qt6/qml)
    else args=(--import disable); fi
    "$QMMLINT" "${args[@]}" "$f" >"$log" 2>&1 || printf '%s\n' "$f"
}
lint_many() {
    local logdir="$1" importdir="$2"; shift 2
    [ "$importdir" = "-" ] && importdir=""
    export QMMLINT LINT_TMP="$logdir" LINT_IMPORT_DIR="$importdir"
    export -f _lint_one
    printf '%s\0' "$@" | xargs -0 -r -P "$(nproc)" -n 1 bash -c '_lint_one "$1"' _
}

# --- 1. qmllint ------------------------------------------------------------
# Intenta resolver los imports qs.* vía el VFS que genera quickshell al correr
# ($XDG_RUNTIME_DIR/quickshell/vfs/<hash>/). Sin VFS (CI, shell parada) cae a
# chequeo de sintaxis sin resolver imports.
step "1/6 qmllint (sintaxis QML)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
VFS_QS=""
for d in "$RUNTIME_DIR"/quickshell/vfs/*/qs; do
    [ -f "$d/qmldir" ] && { VFS_QS="$d"; break; }
done
LINT_IMPORTDIR=""
TMPDIR_MERGE=""
if [ -n "$VFS_QS" ]; then
    VFS_ROOT="$(dirname "$VFS_QS")"
    TMPDIR_MERGE="$(mktemp -d)"
    # Copia el árbol generado (tiene qmldir por módulo) y rellena los qmldir
    # que solo existen en el repo (Services, Brightness) junto a sus ficheros.
    cp -a "$VFS_QS" "$TMPDIR_MERGE/qs" 2>/dev/null
    for qmldir in $(cd "$ROOT" && find . -name qmldir); do
        dest="$TMPDIR_MERGE/qs/${qmldir#./}"
        if [ ! -f "$dest" ]; then
            mkdir -p "$(dirname "$dest")"
            cp "$ROOT/$qmldir" "$dest"
        fi
    done
    LINT_IMPORTDIR="$TMPDIR_MERGE"
    echo "  imports: VFS $VFS_ROOT"
else
    # Sin VFS no se pueden resolver qs.*: se silencian solo los avisos de
    # import para no enterrar errores reales de sintaxis.
    LINT_IMPORTDIR=""
    echo "  imports: sin VFS de quickshell (solo sintaxis)"
fi

LINT_TMP="$(mktemp -d)"
LINT_FAILED="$(lint_many "$LINT_TMP" "${LINT_IMPORTDIR:--}" "${QML_FILES[@]}")"
if [ -z "$LINT_FAILED" ]; then
    # Con imports resueltos pueden quedar warnings reales (unused, missing-property);
    # se muestran resumidos sin fallar: lo que falla es la sintaxis (exit code).
    WCOUNT=$(grep -h '^Warning\|^Error' "$LINT_TMP"/*.log 2>/dev/null | wc -l)
    ok "qmllint sintaxis correcta ($WCOUNT avisos informativos)"
    if [ "$WCOUNT" -gt 0 ]; then
        grep -h '^Warning\|^Error' "$LINT_TMP"/*.log 2>/dev/null | sed 's/Warning: //' | head -n 10
        [ "$WCOUNT" -gt 10 ] && echo "  ... ($WCOUNT avisos en total)"
    fi
else
    NFAIL=$(echo "$LINT_FAILED" | wc -l)
    fail "qmllint: $NFAIL ficheros con error de sintaxis"
    echo "$LINT_FAILED" | while IFS= read -r f; do echo "    ${f#"$ROOT"/}"; done
    echo "$LINT_FAILED" | while IFS= read -r f; do
        echo "--- ${f#"$ROOT"/} ---"
        head -n 10 "$LINT_TMP/${f//\//_}.log"
    done
fi
rm -rf "$LINT_TMP"
[ -n "$TMPDIR_MERGE" ] && rm -rf "$TMPDIR_MERGE"

# --- 2. qmlformat -----------------------------------------------------------
step "2/6 qmlformat (formato .qmlformat.ini)"
if [ $FIX -eq 1 ]; then
    printf '%s\0' "${FMT_FILES[@]}" | xargs -0 -r -P "$(nproc)" -n 20 "$QMLFORMAT" -i >/dev/null 2>&1
    ok "qmlformat --fix aplicado"
fi
# Chequeo en paralelo: cada worker imprime los ficheros sucios.
DIRTY_OUT="$(printf '%s\0' "${FMT_FILES[@]}" \
    | xargs -0 -r -P "$(nproc)" -n 1 sh -c '"$1" "$2" 2>/dev/null | diff -q "$2" - >/dev/null 2>&1 || echo "$2"' _ "$QMLFORMAT" \
    | sort)"
mapfile -t DIRTY <<< "$DIRTY_OUT"
# mapfile con heredoc vacío deja un elemento vacío: limpiarlo.
if [ ${#DIRTY[@]} -eq 1 ] && [ -z "${DIRTY[0]}" ]; then DIRTY=(); fi
if [ ${#DIRTY[@]} -eq 0 ]; then
    ok "formato limpio (${#FMT_FILES[@]} ficheros, 1 excluido: ${FMT_EXCLUDE[*]})"
else
    if [ $FIX -eq 1 ]; then
        # Tras --fix no debería quedar nada sucio; si queda, es error real.
        fail "${#DIRTY[@]} ficheros siguen sucios tras --fix"
    else
        fail "${#DIRTY[@]} de $TOTAL_QML ficheros con formato pendiente (corre con --fix)"
    fi
    for f in "${DIRTY[@]:0:15}"; do echo "    ${f#"$ROOT"/}"; done
    [ ${#DIRTY[@]} -gt 15 ] && echo "    ... y $(( ${#DIRTY[@]} - 15 )) más"
fi

# --- 3. convenciones propias -------------------------------------------------
step "3/6 qml-lint-conventions.py (orden Qt)"
CONV_OUT="$(python3 "$ROOT/scripts/qml-lint-conventions.py" 2>&1)"
CONV_EC=$?
CONV_N=$(echo "$CONV_OUT" | grep -oP 'Found \K[0-9]+(?= violation)' || echo "?")
if [ $CONV_EC -eq 0 ]; then
    ok "convenciones limpias"
else
    if [ $STRICT -eq 1 ]; then
        fail "$CONV_N violaciones de convención (--strict)"
        echo "$CONV_OUT" | head -n 20
    else
        warn "$CONV_N violaciones de convención (informativo; usa --strict para fallar, --fix para autofix)"
        echo "$CONV_OUT" | tail -n 10
    fi
fi
if [ $FIX -eq 1 ]; then
    python3 "$ROOT/scripts/qml-lint-conventions.py" --fix >/dev/null 2>&1
    ok "conventions --fix aplicado (re-corre el check para verificar)"
fi

# --- 4. JSON i18n -------------------------------------------------------------
step "4/6 JSON i18n"
if python3 -c "import json,glob,sys; fs=glob.glob('$ROOT/Core/i18n/*.json'); assert fs, 'sin json'; [json.load(open(f)) for f in fs]; print(len(fs))" 2>&1; then
    ok "i18n JSON válido"
else
    fail "i18n JSON roto"
fi

# --- 5. JS ---------------------------------------------------------------------
# Los .js de la shell usan dialecto QML (`.pragma library`), que node no
# entiende. Se validan con qmllint, que sí lo parsea.
step "5/6 JS (qmllint)"
mapfile -d '' JS_FILES < <(find "$ROOT" -name '*.js' -not -path '*/node_modules/*' -print0 | sort -z)
if [ ${#JS_FILES[@]} -eq 0 ]; then
    ok "sin ficheros JS"
else
    JS_TMP="$(mktemp -d)"
    JS_FAILED="$(lint_many "$JS_TMP" "-" "${JS_FILES[@]}")"
    rm -rf "$JS_TMP"
    if [ -z "$JS_FAILED" ]; then
        ok "JS válido (${#JS_FILES[@]} ficheros)"
    else
        fail "sintaxis JS:"
        echo "$JS_FAILED" | while IFS= read -r f; do echo "    ${f#"$ROOT"/}"; done
    fi
fi

# --- 6. M3 / robustez (grep) ----------------------------------------------------
step "6/6 M3 + robustez"
HARDCODED="$(grep -rn --include='*.qml' -E 'color:\s*"#' "$ROOT" || true)"
if [ -z "$HARDCODED" ]; then
    ok "sin colores hardcodeados"
else
    fail "colores hardcodeados (usar Appearance.md3):"
    echo "$HARDCODED" | head -n 10
fi

# --- resumen --------------------------------------------------------------------
echo ""
if [ $FAIL -eq 0 ]; then
    printf '\033[1;32mPASS\033[0m: %d ok, %d avisos\n' "$PASS" "$WARN"
    exit 0
else
    printf '\033[1;31mFAIL\033[0m: %d ok, %d fallos, %d avisos\n' "$PASS" "$FAIL" "$WARN"
    exit 1
fi
