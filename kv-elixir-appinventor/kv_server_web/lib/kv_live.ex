defmodule KvServerWebWeb.KvLive do

  use KvServerWebWeb, :live_view
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
