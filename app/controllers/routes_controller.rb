require 'anthropic'
require 'json'

class RoutesController < ApplicationController
  def new
    # Vista para el formulario de entrada de prompt
  end

  def create
    @prompt = params[:prompt]

    # Verificar que hay un prompt
    if @prompt.blank?
      flash[:error] = "Por favor ingresa una descripción de tu ruta"
      redirect_to new_route_path
      return
    end

    # Procesar el prompt con Claude
    begin
      route_points = process_with_ai(@prompt)

      if route_points.nil? || !route_points.key?(:origin) || !route_points.key?(:destination)
        flash[:error] = "No se pudo interpretar correctamente la ruta. Por favor, sé más específico."
        redirect_to new_route_path
        return
      end

      # Redirigir a la vista del mapa con los puntos extraídos
      redirect_to show_route_path(
        origin: route_points[:origin],
        destination: route_points[:destination],
        waypoints: route_points[:waypoints].join('|'),
        original_prompt: @prompt
      )
    rescue => e
      Rails.logger.error("Error procesando con IA: #{e.message}")
      flash[:error] = "Error al procesar la solicitud. Por favor intenta de nuevo."
      redirect_to new_route_path
    end
  end

  def show
    @origin = params[:origin]
    @destination = params[:destination]
    @waypoints = params[:waypoints].present? ? params[:waypoints].split('|') : []
    @original_prompt = params[:original_prompt]
    @api_key = ENV['GOOGLE_MAPS_API_KEY']

    # Añadir un timestamp para evitar caché
    @timestamp = Time.now.to_i

    # Forzar que la vista no se almacene en caché
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  private

  def process_with_ai(prompt)
    # Configurar el cliente de Anthropic
    puts "ANTHROPIC API_KEY: #{ENV['ANTHROPIC_API_KEY']}"

    client = Anthropic::Client.new(
      access_token: ENV['ANTHROPIC_API_KEY']
    )

    # Preparar el mensaje para Claude con instrucciones específicas
    system_prompt = "Tu tarea es extraer puntos de ruta de la descripción del usuario. La ruta estará en Barranquilla, Colombia. Extrae: 1) punto de origen, 2) puntos intermedios (en orden), y 3) destino final. Responde únicamente en formato JSON con las claves 'origin', 'waypoints' (array), y 'destination'. Añade 'Barranquilla' a cada ubicación para mejor geocodificación."

    user_prompt = "Necesito planificar una ruta en Barranquilla con la siguiente descripción: #{prompt}"

    # Realizar la solicitud a Claude
    response = client.messages(
      parameters: {
        model: "claude-3-7-sonnet-20250219",
        system: system_prompt,
        max_tokens: 1000,
        messages: [
          { role: "user", content: user_prompt }
        ]
      }
    )

    # Extraer y parsear la respuesta JSON
    begin
      content = response["content"].first["text"]
      # Extraer solo el JSON si viene con texto adicional (buscando entre llaves)
      json_match = content.match(/\{.*\}/m)
      json_string = json_match ? json_match[0] : content

      result = JSON.parse(json_string, symbolize_names: true)

      # Asegurar que waypoints es un array
      result[:waypoints] = [] unless result.key?(:waypoints)
      result[:waypoints] = [result[:waypoints]] if result[:waypoints].is_a?(String)

      return result
    rescue JSON::ParserError => e
      Rails.logger.error("Error al parsear JSON: #{e.message}, Respuesta: #{content}")
      # Implementación de fallback básica
      return {
        origin: "No se pudo extraer el origen",
        waypoints: [],
        destination: "No se pudo extraer el destino"
      }
    end
  end
end
