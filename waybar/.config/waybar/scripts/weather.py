#!/usr/bin/python
import requests
import sys
def obtenerClima():
    """
    Obtiene el clima de una ciudad usando la API de OpenWeatherMap.
    """
    api_key = "081b4110041636a59d7c14ed73f54b59"  # Reemplaza con tu clave de API de OpenWeatherMap
    base_url = "http://api.openweathermap.org/data/2.5/weather"

    # Parámetros para la solicitud
    params = {
        "q": sys.argv[1],
        "appid": api_key,
        "units": "metric",  # Cambia a "imperial" para Fahrenheit
        "lang": "es"        # Idioma de respuesta en español
    }

    try:
        respuesta = requests.get(base_url, params=params)
        respuesta.raise_for_status()  # Verifica si la solicitud fue exitosa
        datos = respuesta.json()
        
        # Verifica que los datos principales estén en la respuesta
        if "main" not in datos or "weather" not in datos:
            return "Error: No se encontraron datos de clima."

        # Extrae temperatura y código de clima
        temperatura = datos["main"]["temp"]
        codigo_clima = datos["weather"][0]["id"]

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

        # Asigna el emoji correspondiente o un valor predeterminado
        clima = emojis_clima.get(codigo_clima, "🌍")

        # Salida final formateada
        output = f"{clima} {temperatura}"
        return output

    except requests.exceptions.RequestException as e:
        return f"Error de conexión"
    except KeyError:
        return "Error al procesar los datos de clima."

# Prueba del código
print(obtenerClima())
