#!/usr/bin/env bash
#
# dns-manager.sh — Interfaz Gum para configurar DNS con systemd-resolved
#
# Requisitos: gum, systemd-resolved activo, sudo
#
set -euo pipefail

DROPIN_DIR="/etc/systemd/resolved.conf.d"
DROPIN_FILE="${DROPIN_DIR}/99-dns-manager.conf"

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

check_deps() {
    if ! command -v gum &>/dev/null; then
        echo "Error: 'gum' no está instalado. Instálalo con: sudo pacman -S gum" >&2
        exit 1
    fi
    if ! command -v resolvectl &>/dev/null; then
        echo "Error: 'resolvectl' no encontrado. ¿systemd-resolved está instalado?" >&2
        exit 1
    fi
    if ! systemctl is-active --quiet systemd-resolved; then
        gum style --foreground 212 "Aviso: systemd-resolved no está activo actualmente."
        gum confirm "¿Quieres activarlo ahora?" && sudo systemctl enable --now systemd-resolved
    fi
}

title() {
    gum style --border rounded --border-foreground 212 --padding "0 2" --bold "$1"
}

# ---------------------------------------------------------------------------
# Presets: nombre|IP1,IP2|hostname_tls
# ---------------------------------------------------------------------------

PRESETS=(
    "Cloudflare|1.1.1.1,1.0.0.1|cloudflare-dns.com"
    "Google|8.8.8.8,8.8.4.4|dns.google"
    "Quad9 (con filtrado malware)|9.9.9.9,149.112.112.112|dns.quad9.net"
    "AdGuard (bloqueo de anuncios)|94.140.14.14,94.140.15.15|dns.adguard.com"
    "Mullvad (sin logs)|194.242.2.2,194.242.2.3|dns.mullvad.net"
)

pick_preset() {
    local labels=()
    for p in "${PRESETS[@]}"; do
        labels+=("${p%%|*}")
    done
    gum choose --header "Elige un preset de DNS" "${labels[@]}"
}

preset_data() {
    local name="$1"
    for p in "${PRESETS[@]}"; do
        if [[ "${p%%|*}" == "$name" ]]; then
            echo "$p"
            return
        fi
    done
}

# ---------------------------------------------------------------------------
# Construcción de la línea DNS= según haya o no TLS
# ---------------------------------------------------------------------------

build_dns_line() {
    local ips="$1" hostname="$2" use_tls="$3"
    local -a entries=()
    IFS=',' read -ra ip_arr <<< "$ips"
    for ip in "${ip_arr[@]}"; do
        ip="$(echo "$ip" | xargs)"
        if [[ "$use_tls" == "yes" && -n "$hostname" ]]; then
            entries+=("${ip}#${hostname}")
        else
            entries+=("$ip")
        fi
    done
    local IFS=' '
    echo "${entries[*]}"
}

# ---------------------------------------------------------------------------
# Flujo: preset
# ---------------------------------------------------------------------------

flow_preset() {
    title "Configurar DNS mediante preset"

    local choice data name ips hostname
    choice="$(pick_preset)" || return
    data="$(preset_data "$choice")"
    name="${data%%|*}"
    rest="${data#*|}"
    ips="${rest%%|*}"
    hostname="${rest#*|}"

    local use_tls="no"
    if gum confirm "¿Activar DNS over TLS para $name?"; then
        use_tls="yes"
    fi

    local tls_mode="yes"
    if [[ "$use_tls" == "yes" ]]; then
        tls_mode="$(gum choose --header "Modo de DNSOverTLS" \
            "yes (estricto, falla si no hay TLS)" \
            "opportunistic (usa TLS si puede, si no cae a texto plano)")"
        [[ "$tls_mode" == yes* ]] && tls_mode="yes" || tls_mode="opportunistic"
    fi

    local dns_line
    dns_line="$(build_dns_line "$ips" "$hostname" "$use_tls")"

    write_config "$dns_line" "$use_tls" "$tls_mode"
}

# ---------------------------------------------------------------------------
# Flujo: DNS personalizado
# ---------------------------------------------------------------------------

flow_custom() {
    title "Configurar DNS personalizado"

    local use_tls="no"
    if gum confirm "¿Activar DNS over TLS?"; then
        use_tls="yes"
    fi

    local tls_mode="yes"
    if [[ "$use_tls" == "yes" ]]; then
        tls_mode="$(gum choose --header "Modo de DNSOverTLS" \
            "yes (estricto, falla si no hay TLS)" \
            "opportunistic (usa TLS si puede, si no cae a texto plano)")"
        [[ "$tls_mode" == yes* ]] && tls_mode="yes" || tls_mode="opportunistic"
    fi

    # Cada servidor puede tener su propio hostname TLS (SNI), no todos comparten
    # el mismo — ej: dns.rocksdns.ovh / dns2.rocksdns.ovh
    local -a entries=()
    local server_ip server_host add_more="yes"
    while [[ "$add_more" == "yes" ]]; do
        server_ip="$(gum input --placeholder "ej: 82.223.31.111" \
            --header "IP del servidor DNS #$((${#entries[@]} + 1))")"
        if [[ -z "$server_ip" ]]; then
            break
        fi

        if [[ "$use_tls" == "yes" ]]; then
            server_host="$(gum input --placeholder "ej: dns.rocksdns.ovh" \
                --header "Hostname TLS (SNI) para $server_ip")"
            if [[ -z "$server_host" ]]; then
                gum style --foreground 196 "DNS over TLS requiere un hostname para cada IP. Servidor omitido."
            else
                entries+=("${server_ip}#${server_host}")
            fi
        else
            entries+=("$server_ip")
        fi

        gum confirm "¿Añadir otro servidor?" && add_more="yes" || add_more="no"
    done

    if [[ "${#entries[@]}" -eq 0 ]]; then
        gum style --foreground 196 "No se ha indicado ningún servidor DNS. Cancelado."
        return
    fi

    local IFS=' '
    local dns_line="${entries[*]}"

    write_config "$dns_line" "$use_tls" "$tls_mode"
}

# ---------------------------------------------------------------------------
# Escritura de configuración
# ---------------------------------------------------------------------------

write_config() {
    local dns_line="$1" use_tls="$2" tls_mode="$3"

    local content
    content="[Resolve]
DNS=${dns_line}
"
    if [[ "$use_tls" == "yes" ]]; then
        content+="DNSOverTLS=${tls_mode}
"
    else
        content+="DNSOverTLS=no
"
    fi
    content+="Domains=~.
"

    echo
    title "Vista previa de ${DROPIN_FILE}"
    gum style --border normal --padding "1 2" "$content"
    echo

    if ! gum confirm "¿Aplicar esta configuración?"; then
        gum style --foreground 212 "Cancelado, no se ha escrito nada."
        return
    fi

    sudo mkdir -p "$DROPIN_DIR"
    echo "$content" | sudo tee "$DROPIN_FILE" >/dev/null
    sudo systemctl restart systemd-resolved

    gum style --foreground 82 --bold "Configuración aplicada correctamente."
    resolvectl status | gum pager
}

# ---------------------------------------------------------------------------
# Ver estado actual
# ---------------------------------------------------------------------------

flow_status() {
    title "Estado actual de resolución DNS"
    resolvectl status | gum pager
}

# ---------------------------------------------------------------------------
# Restaurar valores por defecto
# ---------------------------------------------------------------------------

flow_reset() {
    title "Restaurar configuración por defecto"
    if [[ ! -f "$DROPIN_FILE" ]]; then
        gum style --foreground 212 "No hay ninguna configuración personalizada activa."
        return
    fi
    if gum confirm "Esto eliminará ${DROPIN_FILE} y volverá a la configuración del sistema. ¿Continuar?"; then
        sudo rm -f "$DROPIN_FILE"
        sudo systemctl restart systemd-resolved
        gum style --foreground 82 "Configuración restaurada. DNS controlado de nuevo por systemd-resolved.conf / DHCP."
    fi
}

# ---------------------------------------------------------------------------
# Menú principal
# ---------------------------------------------------------------------------

main_menu() {
    while true; do
        clear
        gum style --border double --border-foreground 99 --padding "1 4" --bold \
            "Gestor de DNS — systemd-resolved"

        local option
        option="$(gum choose \
            "Aplicar preset de DNS" \
            "DNS personalizado" \
            "Ver estado actual" \
            "Restaurar configuración por defecto" \
            "Salir")"

        case "$option" in
            "Aplicar preset de DNS") flow_preset ;;
            "DNS personalizado") flow_custom ;;
            "Ver estado actual") flow_status ;;
            "Restaurar configuración por defecto") flow_reset ;;
            "Salir"|"") echo "Hasta luego."; exit 0 ;;
        esac

        echo
        gum confirm "¿Volver al menú principal?" || exit 0
    done
}

check_deps
main_menu
