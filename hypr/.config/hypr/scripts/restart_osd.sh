#!/bin/bash

LOG_FILE="/tmp/swayosd.log"
APP_NAME="swayosd-server"

# Matar instancias anteriores colgadas (si las hay)
#while pgrep -x "$APP_NAME" > /dev/null; do
    #echo "🛑 Matando instancia colgada de $APP_NAME..."
    #systemctl restart --user swayosd
    #sleep 0.5
#done
systemctl restart --user swayosd
sleep 1

# Borrar log anterior
rm -f "$LOG_FILE"

# Lanzar en segundo plano de forma permanente (sin timeout)
echo "🚀 Iniciando $APP_NAME..."
nohup "$APP_NAME" > "$LOG_FILE" 2>&1 & disown

sleep 2

# Verificar que haya arrancado correctamente
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "✅ $APP_NAME está en ejecución"
else
    echo "❌ Error al iniciar $APP_NAME. Revisa el log: $LOG_FILE"
    [[ -f "$LOG_FILE" ]] && tail -10 "$LOG_FILE"
fi
