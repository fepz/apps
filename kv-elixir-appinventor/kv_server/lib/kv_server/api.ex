defmodule KvServer.Api do
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  plug :dispatch

  # Obtener todos los registros
  get "/api/kv" do
    data = KvServer.KvStore.list_all()
    send_json_resp(conn, 200, data)
  end

  # Obtener un valor por clave
  get "/api/kv/:key" do
    value = KvServer.KvStore.get(conn.params["key"])
    if value != nil do
      send_json_resp(conn, 200, %{key: conn.params["key"], value: value})
    else
      send_json_resp(conn, 404, %{error: "Clave no encontrada"})
    end
  end

  # Crear o actualizar un valor
  post "/api/kv" do
    %{"key" => key, "value" => value} = conn.body_params
    KvServer.KvStore.put(key, value)
    send_json_resp(conn, 201, %{key: key, value: value})
  end

  # Eliminar un valor
  delete "/api/kv/:key" do
    KvServer.KvStore.delete(conn.params["key"])
    send_json_resp(conn, 200, %{message: "Clave eliminada"})
  end

  # Respuesta JSON genérica
  defp send_json_resp(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  # Ruta para manejo de errores
  match _ do
    send_json_resp(conn, 404, %{error: "Ruta no encontrada"})
  end
end
