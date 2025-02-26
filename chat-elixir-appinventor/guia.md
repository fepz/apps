Interesante propuesta para crear una aplicación educativa. Vamos a combinar Elixir (excelente para sistemas distribuidos) con App Inventor (ideal para crear aplicaciones móviles de forma visual) para enseñar conceptos básicos de redes y sistemas distribuidos.

Aquí hay una propuesta para desarrollar esta aplicación:

# Concepto de la aplicación

Podríamos crear una aplicación llamada "DistribuRed" que permita a los estudiantes experimentar visualmente con conceptos de sistemas distribuidos a través de:

1. Un servidor backend en Elixir que maneje la lógica distribuida
2. Una interfaz móvil sencilla creada con App Inventor

## Backend con Elixir

Elixir es perfecto para este propósito porque:
- Está basado en Erlang, diseñado específicamente para sistemas distribuidos
- Utiliza el modelo de actores para concurrencia
- Tiene tolerancia a fallos incorporada

## Frontend con App Inventor

App Inventor permitirá a los estudiantes:
- Crear una interfaz visual fácilmente
- Ver en tiempo real los efectos de la comunicación distribuida
- Experimentar sin necesidad de conocimientos profundos de programación

# Implementación Técnica

```elixir
defmodule DistribuRed.Server do
  use GenServer

  # API del cliente
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  def register_node(node_id, name) do
    GenServer.call(__MODULE__, {:register, node_id, name})
  end

  def send_message(from_node, to_node, message) do
    GenServer.call(__MODULE__, {:send_message, from_node, to_node, message})
  end

  def get_messages(node_id) do
    GenServer.call(__MODULE__, {:get_messages, node_id})
  end

  def get_all_nodes() do
    GenServer.call(__MODULE__, :get_nodes)
  end

  def simulate_node_failure(node_id) do
    GenServer.call(__MODULE__, {:node_failure, node_id})
  end

  def simulate_network_delay(delay_ms) do
    GenServer.call(__MODULE__, {:network_delay, delay_ms})
  end

  # Callbacks del GenServer
  @impl true
  def init(:ok) do
    # Estado inicial: nodos, mensajes, estado de la red
    {:ok, %{
      nodes: %{},         # Mapa de nodos activos
      messages: %{},      # Mensajes pendientes por nodo
      failed_nodes: [],   # Nodos caídos
      network_delay: 0    # Retraso de red simulado
    }}
  end

  @impl true
  def handle_call({:register, node_id, name}, _from, state) do
    if Map.has_key?(state.nodes, node_id) do
      {:reply, {:error, :already_registered}, state}
    else
      updated_nodes = Map.put(state.nodes, node_id, %{name: name, status: :online})
      updated_messages = Map.put(state.messages, node_id, [])
      new_state = %{state | nodes: updated_nodes, messages: updated_messages}
      {:reply, {:ok, node_id}, new_state}
    end
  end

  @impl true
  def handle_call({:send_message, from_node, to_node, message}, _from, state) do
    cond do
      not Map.has_key?(state.nodes, from_node) ->
        {:reply, {:error, :unknown_sender}, state}
      not Map.has_key?(state.nodes, to_node) ->
        {:reply, {:error, :unknown_recipient}, state}
      to_node in state.failed_nodes ->
        {:reply, {:error, :node_unavailable}, state}
      true ->
        # Registrar mensaje con timestamp
        new_message = %{
          from: from_node,
          content: message,
          timestamp: DateTime.utc_now(),
          delivered: false
        }

        # Simular retraso de red
        if state.network_delay > 0 do
          Process.sleep(state.network_delay)
        end

        # Actualizar mensajes del nodo destino
        recipient_messages = [new_message | state.messages[to_node]]
        updated_messages = Map.put(state.messages, to_node, recipient_messages)
        new_state = %{state | messages: updated_messages}

        {:reply, {:ok, :message_sent}, new_state}
    end
  end

  @impl true
  def handle_call({:get_messages, node_id}, _from, state) do
    if Map.has_key?(state.nodes, node_id) do
      # Marcar mensajes como entregados
      messages = state.messages[node_id]
      updated_messages = Enum.map(messages, fn msg -> %{msg | delivered: true} end)
      new_messages = Map.put(state.messages, node_id, [])
      new_state = %{state | messages: new_messages}

      {:reply, {:ok, updated_messages}, new_state}
    else
      {:reply, {:error, :unknown_node}, state}
    end
  end

  @impl true
  def handle_call(:get_nodes, _from, state) do
    online_nodes = state.nodes
    |> Map.keys()
    |> Enum.filter(fn node_id -> node_id not in state.failed_nodes end)
    |> Enum.map(fn node_id -> {node_id, state.nodes[node_id].name} end)
    |> Enum.into(%{})

    {:reply, {:ok, online_nodes}, state}
  end

  @impl true
  def handle_call({:node_failure, node_id}, _from, state) do
    if Map.has_key?(state.nodes, node_id) do
      if node_id in state.failed_nodes do
        # Restaurar nodo
        new_failed = Enum.filter(state.failed_nodes, fn n -> n != node_id end)
        new_state = %{state | failed_nodes: new_failed}
        {:reply, {:ok, :node_restored}, new_state}
      else
        # Simular fallo
        new_failed = [node_id | state.failed_nodes]
        new_state = %{state | failed_nodes: new_failed}
        {:reply, {:ok, :node_failed}, new_state}
      end
    else
      {:reply, {:error, :unknown_node}, state}
    end
  end

  @impl true
  def handle_call({:network_delay, delay_ms}, _from, state) do
    new_state = %{state | network_delay: delay_ms}
    {:reply, {:ok, :delay_set}, new_state}
  end
end

# Arranque de la aplicación
defmodule DistribuRed.Application do
  use Application

  def start(_type, _args) do
    children = [
      {DistribuRed.Server, []},
      {Plug.Cowboy, scheme: :http, plug: DistribuRed.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: DistribuRed.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# Router HTTP para la comunicación con App Inventor
defmodule DistribuRed.Router do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  # Registrar un nuevo nodo
  post "/register" do
    %{"node_name" => name} = conn.body_params
    node_id = UUID.uuid4()

    case DistribuRed.Server.register_node(node_id, name) do
      {:ok, id} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{success: true, node_id: id}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{success: false, error: reason}))
    end
  end

  # Obtener todos los nodos disponibles
  get "/nodes" do
    case DistribuRed.Server.get_all_nodes() do
      {:ok, nodes} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{success: true, nodes: nodes}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{success: false, error: reason}))
    end
  end

  # Enviar mensaje
  post "/send" do
    %{"from_node" => from, "to_node" => to, "message" => message} = conn.body_params

    case DistribuRed.Server.send_message(from, to, message) do
      {:ok, :message_sent} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{success: true}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{success: false, error: reason}))
    end
  end

  # Recibir mensajes
  get "/messages/:node_id" do
    node_id = conn.path_params["node_id"]

    case DistribuRed.Server.get_messages(node_id) do
      {:ok, messages} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{success: true, messages: messages}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{success: false, error: reason}))
    end
  end

  # Simular fallo de nodo
  post "/simulate/failure" do
    %{"node_id" => node_id} = conn.body_params

    case DistribuRed.Server.simulate_node_failure(node_id) do
      {:ok, status} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{success: true, status: status}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{success: false, error: reason}))
    end
  end

  # Simular retraso de red
  post "/simulate/delay" do
    %{"delay_ms" => delay} = conn.body_params

    case DistribuRed.Server.simulate_network_delay(delay) do
      {:ok, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{success: true, delay: delay}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{success: false, error: reason}))
    end
  end

  match _ do
    send_resp(conn, 404, "Ruta no encontrada")
  end
end

```

# Diseño en App Inventor

Para el frontend, usaremos App Inventor para crear una interfaz sencilla que permita:

1. Registrarse como un nodo en la red
2. Ver otros nodos disponibles
3. Enviar y recibir mensajes
4. Simular fallos de red y retrasos

El diseño en App Inventor sería similar a este:

1. Pantalla de registro: Donde cada alumno registra su dispositivo como nodo
2. Pantalla principal: Visualización de la red y operaciones
   - Lista de nodos disponibles
   - Área de mensajes
   - Controles para simulaciones

# Conceptos que se pueden enseñar

La aplicación permitirá a los estudiantes comprender de forma práctica:

1. **Comunicación entre nodos**: Cómo los mensajes viajan de un dispositivo a otro
2. **Tolerancia a fallos**: Qué sucede cuando un nodo deja de funcionar
3. **Latencia de red**: Efectos del retraso en la comunicación
4. **Sincronización**: Desafíos al mantener información coherente entre nodos
5. **Sistemas reactivos**: Cómo el sistema responde a eventos en tiempo real

# Ejercicios prácticos

Con esta aplicación, podrías proponer actividades como:

1. **Simulación de gossip protocol**: Los estudiantes deben difundir un mensaje a toda la red
2. **Resistencia a fallos**: Simular caídas de nodos y observar cómo se comporta el sistema
3. **Particiones de red**: Dividir la clase en grupos aislados y ver qué sucede
4. **Consenso distribuido**: Crear un sistema de votación simple

# Próximos pasos

1. Implementar el servidor Elixir (código arriba como base)
2. Crear la interfaz en App Inventor
3. Establecer la comunicación entre ambos mediante HTTP
4. Probar con un grupo pequeño antes de usarlo en clase

¿Te gustaría que profundice en alguna parte específica de esta propuesta? ¿Quizás el diseño de la interfaz en App Inventor o algún concepto particular de sistemas distribuidos?

---

