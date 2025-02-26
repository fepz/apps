defmodule KVServer do
  use GenServer

  # API Cliente
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def list_all do
    GenServer.call(__MODULE__, :list_all)
  end

  # Callbacks del servidor
  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    value = Map.get(state, key, nil)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    new_state = Map.delete(state, key)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list_all, _from, state) do
    {:reply, state, state}
  end
end

defmodule KVApi do
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
    data = KVServer.list_all()
    send_json_resp(conn, 200, data)
  end

  # Obtener un valor por clave
  get "/api/kv/:key" do
    value = KVServer.get(conn.params["key"])
    if value != nil do
      send_json_resp(conn, 200, %{key: conn.params["key"], value: value})
    else
      send_json_resp(conn, 404, %{error: "Clave no encontrada"})
    end
  end

  # Crear o actualizar un valor
  post "/api/kv" do
    %{"key" => key, "value" => value} = conn.body_params
    KVServer.put(key, value)
    send_json_resp(conn, 201, %{key: key, value: value})
  end

  # Eliminar un valor
  delete "/api/kv/:key" do
    KVServer.delete(conn.params["key"])
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

  def start do
    Logger.info("Iniciando servidor KV en http://localhost:4000")
    KVServer.start_link()
    Plug.Cowboy.http(__MODULE__, [], port: 4000)
  end
end
