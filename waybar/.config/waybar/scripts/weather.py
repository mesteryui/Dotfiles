#!/usr/bin/python
import requests
import sys
import locale
def leer_fichero_api()-> str:
    with open("clave.txt","r") as archivo:
        return archivo.read()

def escribir_fichero_api(api_key:str):
    with open("clave.txt","w") as archivo:
        archivo.write(api_key)

def obtener_parametro():
    """
    Funcion que nos permite sacar el parametro y si el parametro cumple unas condiciones hacer otra cosa
    """
    if len(sys.argv)>1:
        ciudad = str(sys.argv[1])
        if ciudad == "--help":
            print("Ayuda de weather.py\n")
            print("Obtiene informacion del clima en un json que waybar puede interpretar para mostrarlo en la barra con toda la info\n")
            print("--help: Muestra la ayuda\n")
            print("--add-apikey: Nos permite añadir una llave api para poder usar esto. SE BORRARA SI YA HAY UNA\n")
            print("current: Muestra datos en referencia a ubicacion actual lo mismo que no poner nada o eso se busca")
            exit(0)
        elif ciudad == "--add-apikey":
            if len(sys.argv)>2:
                escribir_fichero_api(str(sys.argv[2]))
                exit(0)
            else:
                print("Para guardar una clave api use la siguiente sintaxis:")
                print("weather.py --add-apikey CLAVEAÑADIR")
                exit(0)
        else:
            return ciudad

    else: 
        return '' 
    
def obtener_ubicacion():
    url = "http://ip-api.com/json"
    try:
        respuesta = requests.get(url)
        datos = respuesta.json()
        ciudad = datos.get("city","Vigo")
        return ciudad
    except Exception:
        return "Error al obtener la ubicacion de forma automatica"


def obtener_ciudad(ciudad):
    if ciudad == "current" or ciudad == '':
        ciudad = obtener_ubicacion()
    return ciudad

ciudad = obtener_ciudad(obtener_parametro())

def obtenerClima():
    """
    Obtiene el clima de una ciudad usando la API de OpenWeatherMap.
    """
    api_key = "081b4110041636a59d7c14ed73f54b59"
    if api_key is None:
        print("No tienes clave api")
        exit(1)
    base_url = "http://api.openweathermap.org/data/2.5/weather"
        # Parámetros para la solicitud"
    language = locale.getlocale()[0][0:2]
    params = {
        "q": ciudad,
        "appid": api_key,
        "units": "metric",  # Cambia a "imperial" para Fahrenheit
        "lang": language,       # Idioma de respuesta en español
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

        # Asigna el emoji correspondiente o un valor predeterminado
        clima = emojis_clima.get(codigo_clima, "🌍")

        # Salida final formateada
        output = f"{clima} {temperatura}"
        return output,descripcion,temperatura

    except requests.exceptions.RequestException:
        return f"Error de conexión"
    except KeyError:
        return "Error al procesar los datos de clima."

# Prueba del código
clima_datos = obtenerClima()

print(f'{{"text": "{clima_datos[0]}", "tooltip": "Clima: {clima_datos[1].title()}\\nCiudad: {ciudad.title()}\\nTemperatura: {clima_datos[2]}"}}')
