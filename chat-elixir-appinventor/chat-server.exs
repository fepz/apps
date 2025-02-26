Vamos a profundizar en la implementación del servidor Elixir. Para configurar un proyecto completo, necesitaremos seguir estos pasos:

# Configuración del proyecto Elixir

## 1. Crear un nuevo proyecto

Primero, necesitamos crear un nuevo proyecto Elixir:

```bash
mix new distribu_red --sup
cd distribu_red
```

El flag `--sup` nos genera automáticamente un árbol de supervisión, ideal para aplicaciones robustas y tolerantes a fallos.

## 2. Añadir dependencias

Edita el archivo `mix.exs` para añadir las dependencias necesarias:

```elixir
defp deps do
  [
    {:plug_cowboy, "~> 2.6"},      # Para crear el servidor HTTP
    {:jason, "~> 1.4"},            # Para codificación/decodificación JSON
    {:uuid, "~> 1.1"}              # Para generar IDs únicos
  ]
end
```

Instala las dependencias:

```bash
mix deps.get
```

## 3. Estructura del proyecto

El proyecto debe tener esta estructura:

```
distribu_red/
  ├── lib/
  │   ├── distribu_red/
  │   │   ├── server.ex           # Implementación del GenServer
  │   │   └── router.ex           # Router HTTP para API REST
  │   └── distribu_red.ex         # Punto de entrada de la aplicación
  ├── mix.exs                     # Configuración del proyecto
  └── config/                     # Configuraciones adicionales
```

## 4. Implementación del GenServer

El `GenServer` es el corazón de la aplicación. Crea el archivo `lib/distribu_red/server.ex`:

```elixir
defmodule DistribuRed.Server do
  use GenServer
  require Logger

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
    Logger.info("DistribuRed Server iniciando...")
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
    Logger.info("Registrando nodo: #{node_id} (#{name})")

    if Map.has_key?(state.nodes, node_id) do
      {:reply, {:error, :already_registered}, state}
    else
      updated_nodes = Map.put(state.nodes, node_id, %{name: name, status: :online})
      updated_messages = Map.put(state.messages, node_id, [])
      new_state = %{state | nodes: updated_nodes, messages: updated_messages}

      # Notificar a todos los nodos sobre el nuevo miembro
      broadcast_system_message("Nuevo nodo conectado: #{name}", node_id, new_state)

      {:reply, {:ok, node_id}, new_state}
    end
  end

  @impl true
  def handle_call({:send_message, from_node, to_node, message}, _from, state) do
    Logger.info("Mensaje de #{from_node} para #{to_node}: #{message}")

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
          sender_name: state.nodes[from_node].name,
          content: message,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
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
    if node_id in state.failed_nodes do
      {:reply, {:error, :node_unavailable}, state}
    else
      if Map.has_key?(state.nodes, node_id) do
        # Obtener mensajes y marcarlos como entregados
        messages = state.messages[node_id]

        # Actualizar estado eliminando mensajes ya entregados
        new_messages = Map.put(state.messages, node_id, [])
        new_state = %{state | messages: new_messages}

        {:reply, {:ok, messages}, new_state}
      else
        {:reply, {:error, :unknown_node}, state}
      end
    end
  end

  @impl true
  def handle_call(:get_nodes, _from, state) do
    online_nodes = state.nodes
    |> Enum.filter(fn {node_id, _} -> node_id not in state.failed_nodes end)
    |> Enum.map(fn {node_id, node} -> %{id: node_id, name: node.name} end)

    {:reply, {:ok, online_nodes}, state}
  end

  @impl true
  def handle_call({:node_failure, node_id}, _from, state) do
    if Map.has_key?(state.nodes, node_id) do
      if node_id in state.failed_nodes do
        # Restaurar nodo
        Logger.info("Restaurando nodo: #{node_id}")
        new_failed = Enum.filter(state.failed_nodes, fn n -> n != node_id end)
        new_state = %{state | failed_nodes: new_failed}

        # Notificar la recuperación del nodo
        broadcast_system_message("Nodo recuperado: #{state.nodes[node_id].name}", node_id, new_state)

        {:reply, {:ok, :node_restored}, new_state}
      else
        # Simular fallo
        Logger.info("Simulando fallo en nodo: #{node_id}")
        new_failed = [node_id | state.failed_nodes]
        new_state = %{state | failed_nodes: new_failed}

        # Notificar a todos sobre el fallo
        broadcast_system_message("¡Nodo caído!: #{state.nodes[node_id].name}", node_id, new_state)

        {:reply, {:ok, :node_failed}, new_state}
      end
    else
      {:reply, {:error, :unknown_node}, state}
    end
  end

  @impl true
  def handle_call({:network_delay, delay_ms}, _from, state) do
    Logger.info("Configurando retraso de red: #{delay_ms}ms")
    new_state = %{state | network_delay: delay_ms}

    broadcast_system_message("Latencia de red configurada a #{delay_ms}ms", nil, new_state)

    {:reply, {:ok, :delay_set}, new_state}
  end

  # Función auxiliar para enviar mensajes del sistema a todos los nodos
  defp broadcast_system_message(content, excluded_node, state) do
    system_message = %{
      from: "SYSTEM",
      sender_name: "Sistema",
      content: content,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      delivered: false,
      type: :system
    }

    # Enviar a todos los nodos excepto el excluido y los caídos
    Enum.each(state.nodes, fn {node_id, _} ->
      if node_id != excluded_node && node_id not in state.failed_nodes do
        node_messages = [system_message | state.messages[node_id]]
        Map.put(state.messages, node_id, node_messages)
      end
    end)
  end
end
```

## 5. Implementación del Router HTTP

Crea el archivo `lib/distribu_red/router.ex` para exponer la API:

```elixir
defmodule DistribuRed.Router do
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  # Habilitar CORS para comunicación con App Inventor
  plug CORSPlug, origin: "*"

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

  # Página inicial informativa
  get "/" do
    html = """
    <!DOCTYPE html>
    <html>
      <head>
        <title>DistribuRed API</title>
        <style>
          body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
          h1 { color: #333; }
          h2 { color: #666; }
          pre { background: #f4f4f4; padding: 10px; border-radius: 5px; }
        </style>
      </head>
      <body>
        <h1>DistribuRed - API para Sistemas Distribuidos</h1>
        <p>Esta es la API del servidor Elixir para la aplicación DistribuRed.</p>

        <h2>Endpoints disponibles:</h2>
        <ul>
          <li><code>POST /register</code> - Registrar un nuevo nodo</li>
          <li><code>GET /nodes</code> - Obtener todos los nodos</li>
          <li><code>POST /send</code> - Enviar un mensaje</li>
          <li><code>GET /messages/:node_id</code> - Recibir mensajes</li>
          <li><code>POST /simulate/failure</code> - Simular fallo de nodo</li>
          <li><code>POST /simulate/delay</code> - Simular retraso de red</li>
        </ul>

        <h2>Estado actual:</h2>
        <p>Servidor activo y escuchando en el puerto 4000</p>
      </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  match _ do
    send_resp(conn, 404, "Ruta no encontrada")
  end
end
```

## 6. Configuración de la aplicación

Edita el archivo `lib/distribu_red.ex` para configurar el punto de entrada:

```elixir
defmodule DistribuRed do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Iniciando aplicación DistribuRed...")
    children = [
      # GenServer principal
      {DistribuRed.Server, []},
      # Servidor HTTP con Cowboy
      {Plug.Cowboy, scheme: :http, plug: DistribuRed.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: DistribuRed.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## 7. Actualizar la configuración de la aplicación

Edita el archivo `mix.exs` para asegurarte de que la aplicación arranca automáticamente:

```elixir
def application do
  [
    mod: {DistribuRed, []},
    extra_applications: [:logger]
  ]
end
```

## 8. Añadir soporte CORS

Añade el paquete CORS para permitir la comunicación desde App Inventor:

```elixir
# En mix.exs, añade a las dependencias:
{:cors_plug, "~> 3.0"}
```

## 9. Ejecutar la aplicación

Para iniciar el servidor:

```bash
mix run --no-halt
```

O en modo de desarrollo con recarga automática:

```bash
mix phx.server
```

## 10. Pruebas y documentación

Para facilitar pruebas, puedes crear un archivo Markdown con ejemplos de uso:

```markdown
# Ejemplos de uso de la API DistribuRed

## Registrar un nuevo nodo
```
curl -X POST http://localhost:4000/register \
  -H "Content-Type: application/json" \
  -d '{"node_name": "Dispositivo de Juan"}'
```

## Obtener lista de nodos
```
curl http://localhost:4000/nodes
```

## Enviar mensaje
```
curl -X POST http://localhost:4000/send \
  -H "Content-Type: application/json" \
  -d '{"from_node": "NODE_ID_1", "to_node": "NODE_ID_2", "message": "Hola, ¿cómo estás?"}'
```

## Recibir mensajes
```
curl http://localhost:4000/messages/NODE_ID
```

## Simular fallo de nodo
```
curl -X POST http://localhost:4000/simulate/failure \
  -H "Content-Type: application/json" \
  -d '{"node_id": "NODE_ID"}'
```

## Simular retraso de red
```
curl -X POST http://localhost:4000/simulate/delay \
  -H "Content-Type: application/json" \
  -d '{"delay_ms": 2000}'
```
```

## Conceptos implementados

Esta implementación de servidor Elixir muestra varios conceptos importantes de sistemas distribuidos:

1. **Nodos y comunicación**: Cada estudiante representa un nodo en la red
2. **Tolerancia a fallos**: Los nodos pueden fallar y recuperarse
3. **Simulación de latencia**: Se puede ajustar el retraso para ver sus efectos
4. **Estado compartido**: El GenServer mantiene el estado global del sistema
5. **Mensajería asíncrona**: Los mensajes se envían y reciben de forma asíncrona

## Mejoras potenciales

Para hacer este servidor más completo, podrías considerar:

1. **Persistencia**: Guardar mensajes y estado en disco
2. **Autenticación**: Añadir tokens de autenticación simples
3. **Métricas**: Mostrar estadísticas de uso
4. **Particiones de red**: Simular grupos aislados de nodos
5. **WebSockets**: Para comunicación en tiempo real

¿Te gustaría que profundice en algún aspecto específico de la implementación o que pasemos a explicar la parte de App Inventor?
