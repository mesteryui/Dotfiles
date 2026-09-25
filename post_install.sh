#!/usr/bin/env bash

# ==============================================================================
# Script de Post-Instalación para Arch Linux
# Modular, idempotente y portable: funciona desde cualquier cwd y en
# re-ejecuciones sin romper el sistema.
# ==============================================================================

set -euo pipefail

# --- Configuración y Variables ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGLIST_REPO="$DOTFILES_DIR/pkglists-repos.txt"
PKGLIST_AUR="$DOTFILES_DIR/pklist-aur.txt"

# Si se quiere forzar una lista manual, editar aquí. Por defecto se
# autodetecta todo directorio de primer nivel que parezca paquete stow.
# Se excluyen .git y similares.
STOW_EXCLUDE=( ".git" ".github" )

SERVICES=(
    hypridle.service
    awww.service
)

# Flags (para automatizar en cualquier sistema / CI)
# Solo se parsean al ejecutar, no al hacer source (para no cerrar la shell).
ASSUME_YES=0
SKIP_AUR=0
SKIP_CHAOTIC=0
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    for arg in "$@"; do
        case "$arg" in
            -y|--yes|--noconfirm) ASSUME_YES=1 ;;
            --skip-aur) SKIP_AUR=1 ;;
            --skip-chaotic) SKIP_CHAOTIC=1 ;;
            -h|--help)
                echo "Uso: $(basename "$0") [-y|--yes] [--skip-aur] [--skip-chaotic]"
                exit 0
                ;;
            *) echo "Argumento desconocido: $arg" >&2; exit 1 ;;
        esac
    done
fi

# --- Funciones de Utilidad (UI) ---
# Funcionan con y sin gum (gum puede no existir al inicio).
log_info()    { if command -v gum &>/dev/null; then gum style --foreground 33 "󰋼 $1"; else printf '\033[34m[INFO]\033[0m %s\n' "$1"; fi; }
log_success() { if command -v gum &>/dev/null; then gum style --foreground 46 "󰄬 $1"; else printf '\033[32m[OK]\033[0m %s\n' "$1"; fi; }
log_error()   { if command -v gum &>/dev/null; then gum style --foreground 196 "󰅙 $1" >&2; else printf '\033[31m[ERROR]\033[0m %s\n' "$1" >&2; fi; }
log_warn()    { if command -v gum &>/dev/null; then gum style --foreground 214 "󱈸 $1"; else printf '\033[33m[WARN]\033[0m %s\n' "$1"; fi; }

confirm_yes() {
    # $1 = pregunta. Respeta -y/--yes y entornos no interactivos.
    if [[ "$ASSUME_YES" -eq 1 ]]; then return 0; fi
    if [[ ! -t 0 ]]; then return 1; fi
    if command -v gum &>/dev/null; then
        gum confirm "$1"
    else
        read -rp "$1 [s/N]: " ans
        [[ "$ans" =~ ^[SsYy]$ ]]
    fi
}

# --- Pre-chequeos ---
check_system() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        log_error "Este script solo funciona en Linux."
        exit 1
    fi
    if ! command -v pacman &>/dev/null; then
        log_error "pacman no encontrado. Este script es solo para Arch Linux (o derivadas como CachyOS)."
        exit 1
    fi
    if ! command -v sudo &>/dev/null; then
        log_error "sudo no encontrado. Instálalo y configura tu usuario antes de continuar."
        exit 1
    fi
    if ! sudo -v; then
        log_error "No se pudo obtener privilegios con sudo. Abortando."
        exit 1
    fi
    # Mantener sudo vivo durante instalaciones largas
    while true; do sudo -n true 2>/dev/null || break; sleep 60; done &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

is_excluded() {
    local name="$1" e
    for e in "${STOW_EXCLUDE[@]}"; do
        [[ "$name" == "$e" ]] && return 0
    done
    return 1
}

discover_stow_modules() {
    local dir base
    for dir in "$DOTFILES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        base="$(basename "$dir")"
        is_excluded "$base" && continue
        # Un paquete stow válido contiene al menos un fichero/dir oculto (.config, .bashrc, ...)
        # o cualquier contenido versionable. Exigimos que no esté vacío.
        if [[ -z "$(ls -A "$dir")" ]]; then
            continue
        fi
        printf '%s\n' "$base"
    done
}

# --- Inicialización ---
prepare_env() {
    log_info "Preparando entorno de instalación..."

    # gum primero para la UI; si falla, los logs usan fallback automáticamente
    if ! command -v gum &>/dev/null; then
        echo "Instalando gum para una mejor interfaz..."
        sudo pacman -S --needed --noconfirm gum || log_warn "No se pudo instalar gum, se usará salida simple."
    fi

    # git + stow: chequear como comandos
    local cmd
    for cmd in git stow; do
        if ! command -v "$cmd" &>/dev/null; then
            log_info "Instalando dependencia faltante: $cmd"
            sudo pacman -S --needed --noconfirm "$cmd" || { log_error "No se pudo instalar $cmd."; exit 1; }
        fi
    done

    # base-devel es un grupo, no un comando: chequear vía pacman
    if ! pacman -Qg base-devel &>/dev/null; then
        log_info "Instalando grupo base-devel (necesario para AUR)..."
        sudo pacman -S --needed --noconfirm base-devel || log_warn "No se pudo instalar base-devel completo."
    fi
}

# --- Repositorios y Paquetes ---
enable_chaotic_aur() {
    if [[ "$SKIP_CHAOTIC" -eq 1 ]]; then
        log_warn "Configuración de Chaotic-AUR omitida por flag."
        return
    fi
    if grep -q "^\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null; then
        log_success "Chaotic-AUR ya está configurado."
        return
    fi

    log_info "Configurando Chaotic-AUR..."
    if ! sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com; then
        log_error "No se pudo recibir la llave de Chaotic-AUR. Revisa tu conexión/DNS."
        return 1
    fi
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                               'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    # Backup antes de tocar pacman.conf (idempotente: no duplicar bloque)
    sudo cp -a /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%Y%m%d-%H%M%S)"
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    sudo pacman -Syu --noconfirm || log_warn "La actualización completa falló; continúa bajo tu responsabilidad."
}

# Lee una pkglists ignorando comentarios, líneas vacías y espacios/CR.
read_pkglist() {
    local file="$1"
    sed -e 's/#.*//' -e 's/\r//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" | grep -v '^$'
}

install_repo_packages() {
    if [[ ! -f "$PKGLIST_REPO" ]]; then
        log_error "Archivo $PKGLIST_REPO no encontrado."
        return 1
    fi

    log_info "Instalando paquetes de repositorios oficiales..."
    mapfile -t pkgs < <(read_pkglist "$PKGLIST_REPO")
    if [[ "${#pkgs[@]}" -eq 0 ]]; then
        log_warn "Lista de paquetes vacía: $PKGLIST_REPO"
        return 0
    fi

    # Intento en bloque (rápido). Si falla (p.ej. un paquete CachyOS en Arch
    # vainilla o un nombre renombrado), reintento paquete por paquete para
    # instalar todo lo posible sin abortar por set -e.
    if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
        log_success "Paquetes de repositorios instalados."
    else
        log_warn "Instalación en bloque falló; reintentando paquete por paquete..."
        local pkg failed=()
        for pkg in "${pkgs[@]}"; do
            if ! sudo pacman -S --needed --noconfirm "$pkg"; then
                failed+=("$pkg")
            fi
        done
        if [[ "${#failed[@]}" -gt 0 ]]; then
            log_warn "No se pudieron instalar (${#failed[@]}): ${failed[*]}"
            log_warn "Revisa si necesitas el repo CachyOS/Chaotic o si el nombre cambió."
        else
            log_success "Todos los paquetes instalados al reintentar."
        fi
    fi
}

install_paru() {
    if command -v paru &>/dev/null; then
        log_success "Paru ya está instalado."
        return 0
    fi

    if ! confirm_yes "Paru no está instalado. ¿Deseas instalarlo ahora?"; then
        log_warn "Instalación de Paru omitida."
        return 0
    fi

    log_info "Instalando paru..."
    local temp_dir
    temp_dir="$(mktemp -d)"
    if ! git clone https://aur.archlinux.org/paru.git "$temp_dir"; then
        log_error "No se pudo clonar paru. Revisa tu conexión."
        rm -rf "$temp_dir"
        return 1
    fi
    if ! (cd "$temp_dir" && makepkg -si --noconfirm); then
        log_error "Falló la compilación de paru."
        rm -rf "$temp_dir"
        return 1
    fi
    rm -rf "$temp_dir"
    log_success "Paru instalado."
}

install_aur_packages() {
    if [[ "$SKIP_AUR" -eq 1 ]]; then
        log_warn "Paquetes AUR omitidos por flag."
        return 0
    fi
    if ! command -v paru &>/dev/null; then
        log_warn "Omitiendo paquetes AUR porque paru no está instalado."
        return 0
    fi

    if [[ ! -f "$PKGLIST_AUR" ]]; then
        log_error "Archivo $PKGLIST_AUR no encontrado."
        return 1
    fi

    log_info "Instalando paquetes desde AUR..."
    mapfile -t pkgs < <(read_pkglist "$PKGLIST_AUR")
    if [[ "${#pkgs[@]}" -eq 0 ]]; then
        log_warn "Lista AUR vacía, nada que hacer."
        return 0
    fi

    if paru -S --needed --noconfirm "${pkgs[@]}"; then
        log_success "Paquetes AUR instalados."
    else
        log_warn "Instalación AUR en bloque falló; reintentando uno por uno..."
        local pkg failed=()
        for pkg in "${pkgs[@]}"; do
            paru -S --needed --noconfirm "$pkg" || failed+=("$pkg")
        done
        [[ "${#failed[@]}" -gt 0 ]] && log_warn "Fallaron AUR: ${failed[*]}"
    fi
}

# --- Configuración del Sistema ---
# Mueve a backup los ficheros regulares que bloquearían a stow.
# Sin esto, stow aborta en cualquier sistema con configs preexistentes.
backup_stow_conflicts() {
    local module="$1"
    local backup_root="$2"
    local src rel target backup_path
    while IFS= read -r -d '' src; do
        rel="${src#"$DOTFILES_DIR/$module"/}"
        target="$HOME/$rel"
        # Existe (o es symlink roto) y NO es ya un link a nuestro dotfiles -> backup
        if [[ -e "$target" || -L "$target" ]]; then
            if [[ -L "$target" && "$(readlink "$target")" == *".dotfiles/$module"* ]]; then
                continue
            fi
            # Si es un link a otro lado o fichero regular, respaldar
            if [[ ! -L "$target" || "$(readlink "$target")" != "$src" ]]; then
                # Solo ficheros/links: los directorios los fusiona stow
                if [[ -f "$target" || -L "$target" ]]; then
                    backup_path="$backup_root/$rel"
                    mkdir -p "$(dirname "$backup_path")"
                    mv "$target" "$backup_path"
                    log_warn "  -> Backup: $target -> $backup_path"
                fi
            fi
        fi
    done < <(find "$DOTFILES_DIR/$module" -mindepth 1 \( -type f -o -type l \) -print0)
}

apply_dotfiles() {
    log_info "Aplicando configuraciones con stow..."
    mapfile -t modules < <(discover_stow_modules)
    if [[ "${#modules[@]}" -eq 0 ]]; then
        log_warn "No se encontraron módulos stow en $DOTFILES_DIR."
        return 0
    fi

    local backup_root="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
    local module failed=()
    for module in "${modules[@]}"; do
        log_info "  -> Stowing $module"
        # -d = directorio de dotfiles, -t = destino. Así funciona desde
        # cualquier cwd. -R = restow (idempotente en re-ejecuciones).
        if stow -d "$DOTFILES_DIR" -t "$HOME" -R "$module" 2>/dev/null; then
            continue
        fi
        log_warn "  -> Conflicto en $module, respaldando ficheros existentes..."
        backup_stow_conflicts "$module" "$backup_root"
        if ! stow -d "$DOTFILES_DIR" -t "$HOME" -R "$module"; then
            log_warn "  -> Error persistente en $module aun tras backup."
            failed+=("$module")
        fi
    done

    if [[ "${#failed[@]}" -gt 0 ]]; then
        log_warn "Módulos con problemas: ${failed[*]}"
        log_warn "Tip: 'stow -d $DOTFILES_DIR -t \$HOME -R <modulo>' muestra el conflicto exacto."
    else
        log_success "Dotfiles aplicados."
        [[ -d "$backup_root" ]] && log_info "Backups guardados en $backup_root"
    fi
}

enable_user_services() {
    log_info "Habilitando servicios de usuario..."
    # Recargar tras stow para que systemd vea las nuevas unidades
    systemctl --user daemon-reload 2>/dev/null || log_warn "daemon-reload de usuario falló (¿sesión sin D-Bus?). Continúo."

    local service
    for service in "${SERVICES[@]}"; do
        # Normalizar a nombre con sufijo .service
        [[ "$service" == *.service ]] || service="$service.service"
        if systemctl --user enable "$service" &>/dev/null; then
            log_success "  -> Servicio $service habilitado."
        else
            log_warn "  -> No se pudo habilitar $service (puede que la unidad no exista aún o no haya D-Bus de usuario)."
        fi
    done
}

# --- Función Principal ---
main() {
    check_system
    prepare_env

    enable_chaotic_aur || log_warn "Chaotic-AUR no se configuró; algunos paquetes pueden fallar."
    install_repo_packages || log_warn "Hubo errores instalando paquetes repo; revisa el resumen."

    install_paru || log_warn "Paru no se instaló; se omitirá AUR."
    install_aur_packages || log_warn "Hubo errores instalando paquetes AUR."

    apply_dotfiles
    enable_user_services

    if command -v gum &>/dev/null; then
        gum style --foreground 46 --border rounded --padding "1 2" \
            "¡Proceso completado! Revisa avisos arriba y reinicia para aplicar todo."
    else
        log_success "¡Proceso completado! Revisa avisos arriba y reinicia para aplicar todo."
    fi
}

# Ejecutar script (solo si no se está haciendo source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
