#!/usr/bin/env bash

# ==============================================================================
# Script de Post-Instalación para Arch Linux
# Mejorado para: Modularidad, Idempotencia y Claridad.
# ==============================================================================

set -euo pipefail

# --- Configuración y Variables ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGLIST_REPO="pkglists-repos.txt"
PKGLIST_AUR="pklist-aur.txt"

# Listas de módulos para stow y servicios para systemd
STOW_MODULES=(
    hypr rofi systemd kitty fastfetch emacs yazi matugen 
    zathura lsd cava quickshell fish starship bash btop uwsm bat
)

SERVICES=(
    hypridle awww
)

# --- Funciones de Utilidad (UI) ---
log_info()    { gum style --foreground 33 "󰋼 $1"; }
log_success() { gum style --foreground 46 "󰄬 $1"; }
log_error()   { gum style --foreground 196 "󰅙 $1"; }
log_warn()    { gum style --foreground 214 "󱈸 $1"; }

# --- Inicialización ---
prepare_env() {
    clear
    log_info "Preparando entorno de instalación..."
    
    # Asegurar que gum esté instalado primero
    if ! command -v gum &> /dev/null; then
        echo "Instalando gum para una mejor interfaz..."
        sudo pacman -S --needed --noconfirm gum
    fi

    # Comprobar dependencias críticas
    local deps=(git stow base-devel)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_info "Instalando dependencia faltante: $dep"
            sudo pacman -S --needed --noconfirm "$dep"
        fi
    done
}

# --- Repositorios y Paquetes ---
enable_chaotic_aur() {
    if grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        log_success "Chaotic-AUR ya está configurado."
        return
    fi

    log_info "Configurando Chaotic-AUR..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB 
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                               'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Syu --noconfirm
}

install_repo_packages() {
    if [[ -f "$PKGLIST_REPO" ]]; then
        log_info "Instalando paquetes de repositorios oficiales..."
        sudo pacman -S --needed --noconfirm - < "$PKGLIST_REPO"
    else
        log_error "Archivo $PKGLIST_REPO no encontrado."
    fi
}

install_paru() {
    if command -v paru &> /dev/null; then
        log_success "Paru ya está instalado."
        return
    fi

    if gum confirm "Paru no está instalado. ¿Deseas instalarlo ahora?"; then
        log_info "Instalando paru..."
        local temp_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/paru.git "$temp_dir"
        (cd "$temp_dir" && makepkg -si --noconfirm)
        rm -rf "$temp_dir"
    else
        log_warn "Instalación de Paru omitida."
    fi
}

install_aur_packages() {
    if ! command -v paru &> /dev/null; then
        log_warn "Omitiendo paquetes AUR porque paru no está instalado."
        return
    fi

    if [[ -f "$PKGLIST_AUR" ]]; then
        log_info "Instalando paquetes desde AUR..."
        paru -S --needed --noconfirm - < "$PKGLIST_AUR"
    else
        log_error "Archivo $PKGLIST_AUR no encontrado."
    fi
}

# --- Configuración del Sistema ---
apply_dotfiles() {
    log_info "Aplicando configuraciones con stow..."
    for module in "${STOW_MODULES[@]}"; do
        if [[ -d "$DOTFILES_DIR/$module" ]]; then
            log_info "  -> Stowing $module"
            stow "$module"
        else
            log_warn "  -> Directorio $module no encontrado, omitiendo..."
        fi
    done
}

enable_user_services() {
    log_info "Habilitando servicios de usuario..."
    for service in "${SERVICES[@]}"; do
        # Intentamos habilitar, si falla avisamos pero no detenemos el script
        if systemctl --user enable "$service" &> /dev/null; then
            log_success "  -> Servicio $service habilitado."
        else
            log_warn "  -> No se pudo habilitar $service (puede que el archivo de servicio no exista aún)."
        fi
    done
}

# --- Función Principal ---
main() {
    prepare_env
    
    enable_chaotic_aur
    install_repo_packages
    
    install_paru
    install_aur_packages
    
    apply_dotfiles
    enable_user_services

    gum style --foreground 46 --border rounded --padding "1 2" \
        "✅ ¡Proceso completado con éxito! Reinicia para aplicar todos los cambios."
}

# Ejecutar script
main
