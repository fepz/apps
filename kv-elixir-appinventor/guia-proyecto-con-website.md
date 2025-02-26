Voy a crear una interfaz web sencilla en Elixir para interactuar con una base de datos clave-valor. Utilizaré Phoenix, el framework web más popular para Elixir.

Instalar Phoenix con mix archive.install hex phx_new

(luego Start your Phoenix app with:

    $ mix phx.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix phx.server
)

```elixir
# Crear un nuevo proyecto Phoenix (sin Ecto para bases de datos SQL)
# En la terminal:
# mix phx.new kv_web --no-ecto

# lib/kv_web/kv_store.ex
defmodule KvWeb.KvStore do
  use GenServer

  # Cliente API
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
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

  def get_all do
    GenServer.call(__MODULE__, :get_all)
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Callbacks del servidor
  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
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
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{}}
  end
end

# lib/kv_web/application.ex
# Agregar KvStore a la lista de hijos
defmodule KvWeb.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      KvWeb.Telemetry,
      {Phoenix.PubSub, name: KvWeb.PubSub},
      KvWeb.Endpoint,
      KvWeb.KvStore  # Agregamos nuestro GenServer a la supervisión
    ]

    opts = [strategy: :one_for_one, name: KvWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...
end

# lib/kv_web_web/live/kv_live.ex
defmodule KvWebWeb.KvLive do
  use KvWebWeb, :live_view
  alias KvWeb.KvStore

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, 
      key: "", 
      value: "", 
      items: KvStore.get_all(),
      message: nil
    )}
  end

  @impl true
  def handle_event("add", %{"key" => key, "value" => value}, socket) when key != "" do
    KvStore.put(key, value)
    {:noreply, assign(socket, 
      key: "", 
      value: "", 
      items: KvStore.get_all(),
      message: "Item agregado correctamente"
    )}
  end

  @impl true
  def handle_event("add", _, socket) do
    {:noreply, assign(socket, message: "La clave no puede estar vacía")}
  end

  @impl true
  def handle_event("get", %{"key" => key}, socket) when key != "" do
    case KvStore.get(key) do
      nil -> 
        {:noreply, assign(socket, message: "Clave no encontrada")}
      value -> 
        {:noreply, assign(socket, value: value, message: "Item recuperado")}
    end
  end

  @impl true
  def handle_event("get", _, socket) do
    {:noreply, assign(socket, message: "La clave no puede estar vacía")}
  end

  @impl true
  def handle_event("delete", %{"key" => key}, socket) when key != "" do
    KvStore.delete(key)
    {:noreply, assign(socket, 
      items: KvStore.get_all(),
      message: "Item eliminado correctamente"
    )}
  end

  @impl true
  def handle_event("delete", _, socket) do
    {:noreply, assign(socket, message: "La clave no puede estar vacía")}
  end

  @impl true
  def handle_event("get_all", _, socket) do
    {:noreply, assign(socket, 
      items: KvStore.get_all(),
      message: "Todos los items recuperados"
    )}
  end

  @impl true
  def handle_event("clear_items", _, socket) do
    KvStore.clear()
    {:noreply, assign(socket, 
      items: %{},
      message: "Todos los items eliminados"
    )}
  end

  @impl true
  def handle_event("update", %{"key" => key, "value" => value}, socket) do
    {:noreply, assign(socket, key: key, value: value)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-2xl font-bold mb-6">Base de Datos Clave-Valor</h1>
      
      <%= if @message do %>
        <div class="bg-blue-100 border-l-4 border-blue-500 text-blue-700 p-4 mb-4" role="alert">
          <p><%= @message %></p>
        </div>
      <% end %>
      
      <div class="mb-8 p-4 bg-gray-100 rounded">
        <h2 class="text-xl font-semibold mb-4">Operaciones</h2>
        <form phx-change="update">
          <div class="flex gap-4 mb-4">
            <div class="w-1/2">
              <label class="block text-sm font-medium text-gray-700 mb-1">Clave</label>
              <input type="text" name="key" value={@key} class="w-full p-2 border rounded" />
            </div>
            <div class="w-1/2">
              <label class="block text-sm font-medium text-gray-700 mb-1">Valor</label>
              <input type="text" name="value" value={@value} class="w-full p-2 border rounded" />
            </div>
          </div>
        </form>
        
        <div class="flex flex-wrap gap-2">
          <button phx-click="add" phx-value-key={@key} phx-value-value={@value} class="bg-green-500 text-white px-4 py-2 rounded">
            Agregar
          </button>
          <button phx-click="get" phx-value-key={@key} class="bg-blue-500 text-white px-4 py-2 rounded">
            Recuperar
          </button>
          <button phx-click="delete" phx-value-key={@key} class="bg-red-500 text-white px-4 py-2 rounded">
            Eliminar
          </button>
          <button phx-click="get_all" class="bg-purple-500 text-white px-4 py-2 rounded">
            Recuperar Todos
          </button>
          <button phx-click="clear_items" class="bg-gray-500 text-white px-4 py-2 rounded">
            Limpiar Todo
          </button>
        </div>
      </div>
      
      <div class="overflow-x-auto">
        <h2 class="text-xl font-semibold mb-4">Items Almacenados</h2>
        <table class="min-w-full bg-white border">
          <thead>
            <tr>
              <th class="border px-4 py-2 text-left">Clave</th>
              <th class="border px-4 py-2 text-left">Valor</th>
            </tr>
          </thead>
          <tbody>
            <%= for {key, value} <- @items do %>
              <tr>
                <td class="border px-4 py-2"><%= key %></td>
                <td class="border px-4 py-2"><%= value %></td>
              </tr>
            <% end %>
            <%= if Enum.empty?(@items) do %>
              <tr>
                <td colspan="2" class="border px-4 py-2 text-center">No hay items</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end

# lib/kv_web_web/router.ex
defmodule KvWebWeb.Router do
  use KvWebWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KvWebWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KvWebWeb do
    pipe_through :browser

    live "/", KvLive
  end

  # Otras rutas...
end

```

Esta interfaz web utiliza Phoenix LiveView para crear una aplicación reactiva en tiempo real, sin necesidad de escribir JavaScript. La solución incluye:

1. **Un GenServer** (`KvWeb.KvStore`) que implementa la base de datos clave-valor en memoria con operaciones para:
   - Agregar un item (put)
   - Recuperar un item específico (get)
   - Eliminar un item (delete)
   - Recuperar todos los items (get_all)
   - Limpiar todos los items (clear)

2. **Una interfaz LiveView** con:
   - Campos para ingresar clave y valor
   - Botones para todas las operaciones solicitadas
   - Una tabla que muestra todos los items almacenados
   - Mensajes de feedback para el usuario

3. **Configuración mínima** en el router y la aplicación para que todo funcione correctamente

Para utilizar esta aplicación:

1. Crea un nuevo proyecto Phoenix sin Ecto:
   ```
   mix phx.new kv_web --no-ecto
   ```

2. Copia cada uno de los archivos al lugar correspondiente en la estructura del proyecto

3. Inicia el servidor:
   ```
   mix phx.server
   ```

4. Navega a `http://localhost:4000` para usar la interfaz

Esta solución es simple pero funcional, permitiendo todas las operaciones solicitadas con una interfaz clara y minimalista.
