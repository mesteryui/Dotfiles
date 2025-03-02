#!/usr/bin/python
import requests
import sys
import locale
import json
def obtener_api():
   try:
       with open("clave.txt", "r") as f:
            api_key = f.read().strip()
            return api_key if api_key else None
   except FileNotFoundError:
        return None


def escribir_fichero_api(api_key: str):
    with open("clave.txt", "w") as archivo:
        archivo.write(api_key)

def obtener_parametro():
    """
    Función que procesa el parámetro recibido por línea de comandos.
    """
    if len(sys.argv) > 1:
        parametro = str(sys.argv[1])
        if parametro == "--help":
            print("Ayuda de weather.py\n")
            print("Obtiene información del clima en un JSON que waybar puede interpretar para mostrarlo en la barra con toda la info.\n")
            print("--help: Muestra la ayuda")
            print("--add-apikey: Nos permite añadir una llave API para poder usar esto. SE BORRARÁ SI YA HAY UNA")
            print("current: Muestra datos en referencia a la ubicación actual (igual que no poner nada)")
            exit(0)
        elif parametro == "--add-apikey":
            if len(sys.argv) > 2:
                escribir_fichero_api(str(sys.argv[2]))
                exit(0)
            else:
                print("Para guardar una clave API usa la siguiente sintaxis:")
                print("weather.py --add-apikey CLAVEAÑADIR")
                exit(0)
        else:
            return parametro
    else:
        return ''

def obtener_ubicacion():
    url = "https://ip.hostux.net/json"
    try:
        respuesta = requests.get(url)
        datos = respuesta.json()
        ciudad = datos.get("city", "Vigo")
        return ciudad
    except Exception:
        return "Error al obtener la ubicación de forma automática"

def obtener_ciudad(ciudad):
    if ciudad == "current" or ciudad == '':
        ciudad = obtener_ubicacion()
    return ciudad

ciudad = obtener_ciudad(obtener_parametro())

def obtener_clima():
    """
    Obtiene el clima de una ciudad usando la API de OpenWeatherMap.
    """
    api_key = obtener_api()
    if api_key is None:
        print("No tienes clave API")
        exit(1)
    base_url = "http://api.openweathermap.org/data/2.5/weather"
    # Se determina el idioma de la respuesta; si locale no está configurado se usa "es"
    language = locale.getlocale()[0][0:2] if locale.getlocale()[0] else "es"
    params = {
        "q": ciudad,
        "appid": api_key,
        "units": "metric",   # Cambia a "imperial" para Fahrenheit
        "lang": language,    # Idioma de respuesta
    }
    try:
        respuesta = requests.get(base_url, params=params)
        respuesta.raise_for_status()  # Verifica si la solicitud fue exitosa
        datos = respuesta.json()

        if "main" not in datos or "weather" not in datos:
            return "Error: No se encontraron datos de clima."

        temperatura = datos["main"]["temp"]
        codigo_clima = datos["weather"][0]["id"]
        descripcion = datos["weather"][0]["description"]
        # Diccionario de códigos de clima a emojis
        emojis_clima = {
            800: "☀️", 801: "🌤️", 802: "🌥️", 803: "☁️", 804: "☁️",
            500: "🌦️", 501: "🌧️", 502: "🌧️", 503: "🌧️", 504: "🌧️",
            511: "🌨️", 520: "🌦️", 521: "🌧️", 522: "🌧️", 531: "🌧️",
            200: "⛈️", 201: "⛈️", 202: "⛈️", 210: "⛈️", 211: "⛈️",
            212: "⛈️", 221: "⛈️", 230: "🌩️", 231: "🌩️", 232: "🌩️",
            300: "🌧️", 301: "🌧️", 302: "🌧️", 310: "🌦️", 311: "🌦️",
            312: "🌦️", 313: "🌧️", 314: "🌧️", 600: "❄️", 601: "❄️",
            602: "❄️", 611: "🌨️", 612: "🌨️", 613: "🌨️", 615: "🌨️",
            616: "🌨️", 620: "❄️", 621: "❄️", 622: "❄️", 701: "🌫️",
            711: "🌫️", 721: "🌫️", 731: "🌪️", 741: "🌫️", 751: "🏜️",
            761: "🌫️", 762: "🌋"
        }
        clima = emojis_clima.get(codigo_clima, "🌍")
        output = f"{clima} {temperatura}"
        return output, descripcion, temperatura

    except requests.exceptions.RequestException:
        return "Error de conexión"
    except KeyError:
        return "Error al procesar los datos de clima."

# Prueba del código
clima_datos = obtener_clima()
print(f'{{"text": "{clima_datos[0]}", "tooltip": "Clima: {clima_datos[1].title()}\\nCiudad: {ciudad.title()}\\nTemperatura: {clima_datos[2]}"}}')
