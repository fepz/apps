# Guía para configurar el proyecto de servidor KV en Elixir

Esta guía te mostrará paso a paso cómo crear el proyecto Elixir para implementar el servidor de base de datos clave-valor.

## Prerequisitos

Antes de comenzar, asegúrate de tener instalado:
- Elixir (v1.14 o posterior)
- Mix (viene incluido con Elixir)
- Erlang (v25 o posterior)

Puedes verificar las versiones instaladas con:
```bash
elixir --version
```

## Paso 1: Crear un nuevo proyecto con Mix

1. Abre una terminal y navega hasta donde quieras crear el proyecto
2. Crea un nuevo proyecto Mix:

```bash
mix new kv_server --sup
cd kv_server
```

El flag `--sup` crea un proyecto con un árbol de supervisión, lo cual es importante para aplicaciones Elixir tolerantes a fallos.

## Paso 2: Configurar dependencias

Edita el archivo `mix.exs` para agregar las dependencias necesarias:

```elixir
defmodule KvServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :kv_server,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {KvServer.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},  # Para servidor HTTP
      {:jason, "~> 1.4"}         # Para codificar/decodificar JSON
    ]
  end
end
```

Luego, instala las dependencias:

```bash
mix deps.get
```

## Paso 3: Implementar el módulo GenServer para la base de datos KV

Crea un nuevo archivo en `lib/kv_server/kv_store.ex`:

```elixir
defmodule KvServer.KvStore do
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
```

## Paso 4: Implementar la API REST con Plug

Crea un nuevo archivo en `lib/kv_server/api.ex`:

```elixir
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
```

## Paso 5: Configurar la aplicación OTP

Edita el archivo `lib/kv_server/application.ex` generado automáticamente:

```elixir
defmodule KvServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4000")

    children = [
      # Iniciar el almacén KV
      KvServer.KvStore,
      # Iniciar el servidor web
      {Plug.Cowboy, scheme: :http, plug: KvServer.Api, options: [port: port]}
    ]

    opts = [strategy: :one_for_one, name: KvServer.Supervisor]

    # Registrar mensaje de inicio en la consola
    IO.puts("Iniciando servidor KV en http://localhost:#{port}")

    Supervisor.start_link(children, opts)
  end
end
```

## Paso 6: Ejecutar el servidor

Ahora puedes iniciar el servidor con:

```bash
mix run --no-halt
```

O iniciar una sesión interactiva IEx con la aplicación:

```bash
iex -S mix
```

## Paso 7: Probar el servidor

Prueba la API con curl o cualquier cliente HTTP:

```bash
# Guardar un valor
curl -X POST -H "Content-Type: application/json" -d '{"key":"saludo","value":"Hola Mundo"}' http://localhost:4000/api/kv

# Obtener un valor
curl http://localhost:4000/api/kv/saludo

# Listar todos los valores
curl http://localhost:4000/api/kv

# Eliminar un valor
curl -X DELETE http://localhost:4000/api/kv/saludo
```

## Paso 8: Construir una versión de producción (opcional)

Para una versión de producción:

```bash
MIX_ENV=prod mix release
```

Esto generará una versión compilada que puedes ejecutar sin necesidad de tener Elixir instalado en el servidor de producción.

## Consejos adicionales

- **Persistencia**: Este ejemplo usa almacenamiento en memoria. Para persistencia, podrías implementar almacenamiento en disco con `File.write/3` y `File.read/1`.
- **Autenticación**: Para un entorno real, deberías añadir autenticación usando módulos como `Plug.BasicAuth`.
- **CORS**: Si la app móvil se conectará desde otro dominio, deberás habilitar CORS con `Corsica` o un plug personalizado.
- **Seguridad**: Considera validar y sanitizar las entradas para evitar ataques de inyección.


```elixir
defmodule KvServer.KvStoreTest do
  use ExUnit.Case
  alias KvServer.KvStore

  setup do
    # Iniciar un KvStore con nombre único para cada prueba
    {:ok, pid} = KvStore.start_link(name: :test_store)
    # Pasar el pid como estado para las pruebas
    {:ok, %{server: pid}}
  end

  test "almacena y recupera valores", %{server: _server} do
    # Almacenar un valor
    :ok = KvStore.put("test_key", "test_value")

    # Recuperar el valor
    assert KvStore.get("test_key") == "test_value"
  end

  test "devuelve nil para claves inexistentes", %{server: _server} do
    assert KvStore.get("clave_inexistente") == nil
  end

  test "elimina valores", %{server: _server} do
    # Almacenar un valor
    :ok = KvStore.put("key_to_delete", "value")

    # Verificar que existe
    assert KvStore.get("key_to_delete") == "value"

    # Eliminar el valor
    :ok = KvStore.delete("key_to_delete")

    # Verificar que ya no existe
    assert KvStore.get("key_to_delete") == nil
  end

  test "lista todos los valores", %{server: _server} do
    # Vaciar el store para comenzar limpio
    for {key, _} <- KvStore.list_all() do
      KvStore.delete(key)
    end

    # Almacenar varios valores
    KvStore.put("key1", "value1")
    KvStore.put("key2", "value2")
    KvStore.put("key3", "value3")

    # Obtener todos los valores
    all_values = KvStore.list_all()

    # Verificar el contenido
    assert all_values["key1"] == "value1"
    assert all_values["key2"] == "value2"
    assert all_values["key3"] == "value3"
    assert map_size(all_values) == 3
  end
end

defmodule KvServer.ApiTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts KvServer.Api.init([])

  setup do
    # Asegurarse de que el KvStore esté limpio
    for {key, _} <- KvServer.KvStore.list_all() do
      KvServer.KvStore.delete(key)
    end
    :ok
  end

  test "GET /api/kv devuelve lista vacía inicialmente" do
    # Crear una conexión de prueba
    conn = conn(:get, "/api/kv")

    # Enviar la solicitud a través del router
    conn = KvServer.Api.call(conn, @opts)

    # Verificar la respuesta
    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{}
  end

  test "POST /api/kv crea un nuevo par clave-valor" do
    # Crear payload JSON
    payload = Jason.encode!(%{key: "test_key", value: "test_value"})

    # Crear una conexión de prueba con datos
    conn = conn(:post, "/api/kv", payload)
            |> put_req_header("content-type", "application/json")

    # Enviar la solicitud a través del router
    conn = KvServer.Api.call(conn, @opts)

    # Verificar la respuesta
    assert conn.status == 201
    assert Jason.decode!(conn.resp_body) == %{"key" => "test_key", "value" => "test_value"}

    # Verificar que se creó realmente
    assert KvServer.KvStore.get("test_key") == "test_value"
  end

  test "GET /api/kv/:key obtiene un valor específico" do
    # Primero añadir un valor
    KvServer.KvStore.put("fetch_key", "fetch_value")

    # Crear una conexión de prueba
    conn = conn(:get, "/api/kv/fetch_key")

    # Enviar la solicitud a través del router
    conn = KvServer.Api.call(conn, @opts)

    # Verificar la respuesta
    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"key" => "fetch_key", "value" => "fetch_value"}
  end

  test "DELETE /api/kv/:key elimina un valor" do
    # Primero añadir un valor
    KvServer.KvStore.put("delete_key", "delete_value")

    # Crear una conexión de prueba
    conn = conn(:delete, "/api/kv/delete_key")

    # Enviar la solicitud a través del router
    conn = KvServer.Api.call(conn, @opts)

    # Verificar la respuesta
    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"message" => "Clave eliminada"}

    # Verificar que se eliminó realmente
    assert KvServer.KvStore.get("delete_key") == nil
  end

  test "GET /api/kv/:key devuelve 404 para claves inexistentes" do
    # Crear una conexión de prueba para una clave que no existe
    conn = conn(:get, "/api/kv/no_exist")

    # Enviar la solicitud a través del router
    conn = KvServer.Api.call(conn, @opts)

    # Verificar la respuesta
    assert conn.status == 404
    assert Jason.decode!(conn.resp_body) == %{"error" => "Clave no encontrada"}
  end
end

```

Te he preparado una guía detallada para crear el proyecto Elixir para el servidor KV desde cero. La guía incluye:

1. **Configuración del proyecto**:
   - Creación con Mix (el sistema de compilación de Elixir)
   - Configuración de dependencias necesarias (Plug, Cowboy, Jason)

2. **Implementación de componentes clave**:
   - Módulo `KvStore` usando GenServer para almacenar datos
   - API REST con Plug.Router para exponer las operaciones CRUD
   - Configuración de la aplicación OTP con supervisores

3. **Ejecución y pruebas**:
   - Comandos para iniciar el servidor
   - Ejemplos de cómo probar la API con curl
   - Un conjunto de pruebas automatizadas

Aspectos destacados del proyecto:

- **Tolerancia a fallos**: Utiliza supervisores OTP para reiniciar componentes que fallen
- **Concurrencia**: Aprovecha el modelo de actores de Erlang/Elixir para manejar múltiples conexiones
- **API RESTful**: Define endpoints claros para interactuar con la base de datos
- **Parseo de JSON**: Maneja automáticamente la serialización/deserialización
- **Pruebas**: Incluye pruebas unitarias e integración

Para que la aplicación funcione en un entorno de producción, podrías considerar estas mejoras:

1. Implementar persistencia (guardar datos en disco o en una base de datos real)
2. Añadir autenticación para proteger los endpoints
3. Configurar CORS para permitir solicitudes desde dominios específicos
4. Implementar validación de datos de entrada
5. Configurar HTTPS para conexiones seguras

¿Necesitas más detalles sobre alguna parte específica de la implementación o configuración?
