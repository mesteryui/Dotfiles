#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Representacion del pronostico del tiempo
class Pronostico

  EMOJIS_CLIMA = {
    800 => '☀️', 801 => "🌤️", 802 => "🌥️", 803 => "☁️", 804 => "☁️",
    500 => '🌦️', 501 => "🌧️", 502 => "🌧️", 503 => "🌧️", 504 => "🌧️",
    511 => '🌨️', 520 => "🌦️", 521 => "🌧️", 522 => "🌧️", 531 => "🌧️",
    200 => "⛈️", 201 => "⛈️", 202 => "⛈️", 210 => "⛈️", 211 => "⛈️",
    212 => "⛈️", 221 => "⛈️", 230 => "🌩️", 231 => "🌩️", 232 => "🌩️",
    300 => "🌧️", 301 => "🌧️", 302 => "🌧️", 310 => "🌦️", 311 => "🌦️",
    312 => "🌦️", 313 => "🌧️", 314 => "🌧️", 600 => "❄️", 601 => "❄️",
    602 => "❄️", 611 => "🌨️", 612 => "🌨️", 613 => "🌨️", 615 => "🌨️",
    616 => "🌨️", 620 => "❄️", 621 => "❄️", 622 => "❄️", 701 => "🌫️",
    711 => "🌫️", 721 => "🌫️", 731 => "🌪️", 741 => "🌫️", 751 => "🏜️",
    761 => "🌫️", 762 => "🌋"
  }

  attr_reader :ciudad

  # Construccion del Pronostico
  # Args:
  #   ciudad:: String  La ciudad donde se localiza
  #   api_key:: La clave api usada para el proceso
  # Usage:
  #    Pronostico.new("Barcelona","XXXXXXX")
  def initialize(ciudad, api_key)
    @ciudad = ciudad
    @api_key = api_key
    @url = URI("http://api.openweathermap.org/data/2.5/weather")
    @url.query = URI.encode_www_form({
        q: @ciudad,
        appid: @api_key,
        units: 'metric',
        lang: 'es'
      })
  end

  private

  def obtener_datos(datos)
    descripcion = datos['weather'][0]['description']
    codigo = datos["weather"][0]["id"]
    temp = datos["main"]["temp"]
    emoji = EMOJIS_CLIMA[codigo] || "🌈"
    [emoji, descripcion, temp]
  end

  public

  # Obtencion del pronostico
  def obtener_pronostico
    begin
      response = Net::HTTP.get_response(@url)
      datos = JSON.parse(response.body)
      pron = obtener_datos datos
      "{\"text\": \"#{pron[0]} #{pron[2]}\",\"tooltip\": \"Clima: #{pron[1].capitalize}\\nCiudad: #{@ciudad}\\nTemperatura: #{pron[2]}ºC\"}"
    rescue SocketError => e
      '{"text": "🌐 Off"}'
    rescue => e
      '{"text": "🤯"}'
    end
  end
end
if __FILE__ == $PROGRAM_NAME
  p = Pronostico.new 'Vigo', '081b4110041636a59d7c14ed73f54b59'
  puts p.obtener_pronostico
end
