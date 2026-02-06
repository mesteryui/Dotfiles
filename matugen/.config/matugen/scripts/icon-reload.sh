#!/usr/bin/env bash

# Caminho onde o Matugen salvou o HEX
HEX_FILE="$HOME/.cache/matugen/current_primary_color.txt"
TARGET_COLOR=$(cat "$HEX_FILE")

echo "Matugen gerou a cor: $TARGET_COLOR"

# Lista simplificada: Cores Padrão do Papirus (Fallback)
declare -A COLORS=(
    ["black"]="#444444"    ["blue"]="#4285F4"       ["brown"]="#795548"
    ["cyan"]="#00BCD4"     ["green"]="#4CAF50"      ["grey"]="#9E9E9E"
    ["indigo"]="#3F51B5"   ["magenta"]="#E91E63"    ["orange"]="#FF9800"
    ["pink"]="#F06292"     ["red"]="#F44336"        ["teal"]="#009688"
    ["violet"]="#9C27B0"   ["white"]="#F5F5F5"      ["yellow"]="#FFEB3B"
)

# Função para converter HEX para RGB
hex_to_rgb() {
    printf "%d %d %d" 0x${1:1:2} 0x${1:3:2} 0x${1:5:2}
}

# Pegar RGB da cor alvo
read r1 g1 b1 <<< $(hex_to_rgb "$TARGET_COLOR")

min_dist=1000000
best_match="blue"

# Encontrar a cor mais próxima
for name in "${!COLORS[@]}"; do
    hex="${COLORS[$name]}"
    read r2 g2 b2 <<< $(hex_to_rgb "$hex")
    
    # Cálculo de distância (Euclidiana Quadrada)
    dist=$(( (r1-r2)**2 + (g1-g2)**2 + (b1-b2)**2 ))
    
    if (( dist < min_dist )); then
        min_dist=$dist
        best_match=$name
    fi
done

echo "Melhor match: $best_match"

# Aplicar a cor às pastas
papirus-folders -C "$best_match" --theme Papirus-Dark

# --- ATUALIZAÇÃO SUAVE ---

# 1. Atualiza cache do disco
gtk-update-icon-cache -f -t ~/.local/share/icons/Papirus-Dark 2>/dev/null

# 2. Refresh GTK (Apps Gnome/Wayland)
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'

# 3. Refresh XFCE (Thunar)
if command -v xfconf-query &> /dev/null; then
    xfconf-query -c xsettings -p /Net/IconThemeName -s "Adwaita"
    sleep 2.0
    
    xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
fi

# 4. Touch final para garantir
touch ~/.local/share/icons/Papirus-Dark

echo "Ícones atualizados para a cor: $best_match!"
