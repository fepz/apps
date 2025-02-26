Puedo crear un ejemplo que integre Elixir para un backend de base de datos clave-valor y MIT App Inventor para la interfaz móvil. Esto mostrará cómo estas tecnologías pueden comunicarse entre sí.

```elixir
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

```



# Guía: Creación de Cliente KV en App Inventor

Esta guía te muestra cómo crear una aplicación móvil en MIT App Inventor que se comunica con nuestro servidor Elixir para almacenar y recuperar datos en una base de datos clave-valor.

## Paso 1: Crear la Interfaz

1. Abre [MIT App Inventor](http://ai2.appinventor.mit.edu)
2. Crea un nuevo proyecto llamado "ClienteKV"
3. Diseña la interfaz según el siguiente esquema:

### Componentes a añadir:

- **Label**: Título "Base de Datos Clave-Valor"
- **HorizontalArrangement1**:
  - **TextBox** llamado `TextBoxClave` (Hint: "Introducir clave")
  - **TextBox** llamado `TextBoxValor` (Hint: "Introducir valor")
- **HorizontalArrangement2**:
  - **Button** llamado `ButtonGuardar` (Text: "Guardar")
  - **Button** llamado `ButtonObtener` (Text: "Obtener")
  - **Button** llamado `ButtonEliminar` (Text: "Eliminar")
- **Button** llamado `ButtonListarTodos` (Text: "Listar Todos")
- **ListView** llamado `ListViewResultados`
- **Web** (Componente no visible)

## Paso 2: Programar la Lógica (Bloques)

### 1. Variables globales
- Crea una variable global `baseUrl` con el valor `"http://TU_IP_SERVIDOR:4000/api/kv"`

### 2. Función para Guardar (ButtonGuardar.Click)
```
Al hacer clic en ButtonGuardar
  Si TextBoxClave.Text está vacío entonces
    mostrar notificación "La clave no puede estar vacía"
  Si no
    llamar a Web.PostText
      Url: concatenar(baseUrl)
      Texto: crear objeto JSON con "key":TextBoxClave.Text, "value":TextBoxValor.Text
      Tipo MIME: "application/json"
```

### 3. Función para Obtener (ButtonObtener.Click)
```
Al hacer clic en ButtonObtener
  Si TextBoxClave.Text está vacío entonces
    mostrar notificación "La clave no puede estar vacía"
  Si no
    llamar a Web.Get
      Url: concatenar(baseUrl, "/", TextBoxClave.Text)
```

### 4. Función para Eliminar (ButtonEliminar.Click)
```
Al hacer clic en ButtonEliminar
  Si TextBoxClave.Text está vacío entonces
    mostrar notificación "La clave no puede estar vacía"
  Si no
    llamar a Web.Delete
      Url: concatenar(baseUrl, "/", TextBoxClave.Text)
```

### 5. Función para Listar Todos (ButtonListarTodos.Click)
```
Al hacer clic en ButtonListarTodos
  llamar a Web.Get
    Url: baseUrl
```

### 6. Manejar respuestas del servidor

```
Cuando Web.GotText
  Si StatusCode = 200 entonces
    Si Url = baseUrl entonces
      // Respuesta para listar todos
      para cada par en JsonTextDecode(ResponseText)
        añadir a ListViewResultados: concatenar(clave, " : ", valor)
    Si no
      // Respuesta para obtener una clave
      establecer TextBoxValor.Text a JsonTextDecode(ResponseText).get("value")
  Si no
    mostrar notificación concatenar("Error: ", StatusCode)
```

## Paso 3: Probar la Aplicación

1. **Configuración del servidor**:
   - Asegúrate de que tu servidor Elixir esté ejecutándose en una IP accesible desde tu dispositivo móvil
   - Actualiza la variable `baseUrl` con la IP correcta de tu servidor

2. **Conexión**:
   - Conecta tu dispositivo Android al mismo Wi-Fi que tu servidor
   - O utiliza el emulador de App Inventor

3. **Pruebas básicas**:
   - Guarda un par clave-valor
   - Recupera un valor usando su clave
   - Lista todos los pares almacenados
   - Elimina una clave


```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 600">
  <!-- Fondo del teléfono -->
  <rect x="50" y="20" width="300" height="560" rx="20" ry="20" fill="#f0f0f0" stroke="#333" stroke-width="2"/>

  <!-- Pantalla -->
  <rect x="70" y="60" width="260" height="480" fill="#fff" stroke="#ddd"/>

  <!-- Título -->
  <rect x="80" y="80" width="240" height="40" fill="#3F51B5"/>
  <text x="100" y="105" font-family="Arial" font-size="14" fill="white">Base de Datos Clave-Valor</text>

  <!-- TextBox Clave -->
  <rect x="80" y="140" width="115" height="40" fill="#f9f9f9" stroke="#ccc"/>
  <text x="90" y="165" font-family="Arial" font-size="11" fill="#999">Introducir clave</text>

  <!-- TextBox Valor -->
  <rect x="205" y="140" width="115" height="40" fill="#f9f9f9" stroke="#ccc"/>
  <text x="215" y="165" font-family="Arial" font-size="11" fill="#999">Introducir valor</text>

  <!-- Botones -->
  <rect x="80" y="190" width="75" height="35" rx="5" ry="5" fill="#4CAF50"/>
  <text x="95" y="212" font-family="Arial" font-size="11" fill="white">Guardar</text>

  <rect x="165" y="190" width="75" height="35" rx="5" ry="5" fill="#2196F3"/>
  <text x="180" y="212" font-family="Arial" font-size="11" fill="white">Obtener</text>

  <rect x="250" y="190" width="75" height="35" rx="5" ry="5" fill="#F44336"/>
  <text x="265" y="212" font-family="Arial" font-size="11" fill="white">Eliminar</text>

  <!-- Botón Listar Todos -->
  <rect x="80" y="235" width="240" height="35" rx="5" ry="5" fill="#9C27B0"/>
  <text x="160" y="257" font-family="Arial" font-size="11" fill="white">Listar Todos</text>

  <!-- ListView -->
  <rect x="80" y="280" width="240" height="240" fill="#f5f5f5" stroke="#ddd"/>
  <text x="95" y="310" font-family="Arial" font-size="12" fill="#666">clave1 : valor1</text>
  <line x1="80" y1="320" x2="320" y2="320" stroke="#eee" stroke-width="1"/>
  <text x="95" y="340" font-family="Arial" font-size="12" fill="#666">clave2 : valor2</text>
  <line x1="80" y1="350" x2="320" y2="350" stroke="#eee" stroke-width="1"/>
  <text x="95" y="370" font-family="Arial" font-size="12" fill="#666">clave3 : valor3</text>

  <!-- Componentes no visibles (indicados) -->
  <rect x="120" y="540" width="160" height="20" rx="3" ry="3" fill="#ddd"/>
  <text x="140" y="554" font-family="Arial" font-size="10" fill="#555">Componente Web (no visible)</text>
</svg>

```

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 700">
  <!-- Fondo -->
  <rect width="600" height="700" fill="#f5f5f5"/>

  <!-- Variable Global -->
  <rect x="50" y="50" width="200" height="30" rx="5" ry="5" fill="#4a6cd4" stroke="#3a5cb4"/>
  <text x="70" y="70" font-family="Arial" font-size="12" fill="white">initializar global baseUrl</text>
  <rect x="250" y="50" width="250" height="30" rx="5" ry="5" fill="#7d9fe5" stroke="#4a6cd4"/>
  <text x="270" y="70" font-family="Arial" font-size="12" fill="white">"http://TU_IP_SERVIDOR:4000/api/kv"</text>

  <!-- Bloque ButtonGuardar.Click -->
  <rect x="50" y="100" width="250" height="30" rx="5" ry="5" fill="#f89e31" stroke="#d87b1a"/>
  <text x="70" y="120" font-family="Arial" font-size="12" fill="white">cuando ButtonGuardar.Click</text>
  <rect x="70" y="130" width="450" height="120" rx="0" ry="0" fill="#fbc575" stroke="#f89e31" stroke-dasharray="5,2"/>
  <rect x="90" y="150" width="350" height="80" rx="5" ry="5" fill="#f9a842" stroke="#f89e31"/>
  <text x="110" y="170" font-family="Arial" font-size="12" fill="white">si TextBoxClave.Text está vacío entonces</text>
  <rect x="110" y="180" width="300" height="20" rx="0" ry="0" fill="#fbc575" stroke="#f9a842" stroke-dasharray="5,2"/>
  <rect x="130" y="180" width="250" height="20" rx="5" ry="5" fill="#25ae60" stroke="#179447"/>
  <text x="150" y="195" font-family="Arial" font-size="10" fill="white">mostrar notificación "Clave no puede estar vacía"</text>
  <text x="110" y="215" font-family="Arial" font-size="12" fill="white">si no</text>
  <rect x="110" y="225" width="300" height="20" rx="0" ry="0" fill="#fbc575" stroke="#f9a842" stroke-dasharray="5,2"/>
  <rect x="130" y="225" width="250" height="20" rx="5" ry="5" fill="#4a6cd4" stroke="#3a5cb4"/>
  <text x="150" y="240" font-family="Arial" font-size="10" fill="white">llamar Web.PostText con baseUrl y JSON</text>

  <!-- Bloque ButtonObtener.Click -->
  <rect x="50" y="270" width="250" height="30" rx="5" ry="5" fill="#f89e31" stroke="#d87b1a"/>
  <text x="70" y="290" font-family="Arial" font-size="12" fill="white">cuando ButtonObtener.Click</text>
  <rect x="70" y="300" width="450" height="100" rx="0" ry="0" fill="#fbc575" stroke="#f89e31" stroke-dasharray="5,2"/>
  <rect x="90" y="320" width="350" height="60" rx="5" ry="5" fill="#f9a842" stroke="#f89e31"/>
  <text x="110" y="340" font-family="Arial" font-size="12" fill="white">si TextBoxClave.Text está vacío entonces</text>
  <rect x="110" y="350" width="300" height="20" rx="0" ry="0" fill="#fbc575" stroke="#f9a842" stroke-dasharray="5,2"/>
  <rect x="130" y="350" width="250" height="20" rx="5" ry="5" fill="#25ae60" stroke="#179447"/>
  <text x="150" y="365" font-family="Arial" font-size="10" fill="white">mostrar notificación "Clave no puede estar vacía"</text>
  <rect x="130" y="380" width="250" height="20" rx="5" ry="5" fill="#4a6cd4" stroke="#3a5cb4"/>
  <text x="150" y="395" font-family="Arial" font-size="10" fill="white">llamar Web.Get con URL concatenada</text>

  <!-- Bloque ButtonEliminar.Click (similar a Obtener) -->
  <rect x="50" y="420" width="250" height="30" rx="5" ry="5" fill="#f89e31" stroke="#d87b1a"/>
  <text x="70" y="440" font-family="Arial" font-size="12" fill="white">cuando ButtonEliminar.Click</text>
  <rect x="70" y="450" width="450" height="60" rx="0" ry="0" fill="#fbc575" stroke="#f89e31" stroke-dasharray="5,2"/>
  <rect x="130" y="480" width="250" height="20" rx="5" ry="5" fill="#4a6cd4" stroke="#3a5cb4"/>
  <text x="150" y="495" font-family="Arial" font-size="10" fill="white">llamar Web.Delete con URL concatenada</text>

  <!-- Bloque ButtonListarTodos.Click -->
  <rect x="50" y="530" width="250" height="30" rx="5" ry="5" fill="#f89e31" stroke="#d87b1a"/>
  <text x="70" y="550" font-family="Arial" font-size="12" fill="white">cuando ButtonListarTodos.Click</text>
  <rect x="70" y="560" width="450" height="40" rx="0" ry="0" fill="#fbc575" stroke="#f89e31" stroke-dasharray="5,2"/>
  <rect x="90" y="570" width="250" height="20" rx="5" ry="5" fill="#4a6cd4" stroke="#3a5cb4"/>
  <text x="110" y="585" font-family="Arial" font-size="10" fill="white">llamar Web.Get con baseUrl</text>

  <!-- Bloque Web.GotText -->
  <rect x="50" y="620" width="250" height="30" rx="5" ry="5" fill="#f89e31" stroke="#d87b1a"/>
  <text x="70" y="640" font-family="Arial" font-size="12" fill="white">cuando Web.GotText</text>
  <rect x="70" y="650" width="450" height="40" rx="0" ry="0" fill="#fbc575" stroke="#f89e31" stroke-dasharray="5,2"/>
  <rect x="90" y="660" width="350" height="20" rx="5" ry="5" fill="#f9a842" stroke="#f89e31"/>
  <text x="110" y="675" font-family="Arial" font-size="10" fill="white">procesar respuesta JSON y actualizar ListViewResultados</text>
</svg>

```

Este sistema de ejemplo combina Elixir y App Inventor para crear una aplicación de base de datos clave-valor. Vamos a revisar los componentes:

## Servidor Elixir (Backend)
He creado un servidor Elixir que gestiona una base de datos clave-valor en memoria usando:
- `GenServer` para mantener el estado y manejar las operaciones CRUD
- `Plug.Router` para crear una API REST que expone los datos
- Puntos finales (endpoints) para obtener, guardar, listar y eliminar datos

## Aplicación MIT App Inventor (Frontend)
La aplicación móvil incluye:
- Una interfaz de usuario con campos para ingresar claves y valores
- Botones para realizar operaciones CRUD
- Un componente ListView para mostrar resultados
- Bloques de código para manejar la comunicación con la API REST

## Comunicación entre componentes
- La aplicación móvil se comunica con el servidor Elixir a través de peticiones HTTP
- Las operaciones CRUD se mapean a métodos HTTP (GET, POST, DELETE)
- Los datos se intercambian en formato JSON

## Cómo ejecutar este ejemplo
1. Inicia el servidor Elixir ejecutando `KVApi.start()`
2. Construye la aplicación en App Inventor según las instrucciones
3. Asegúrate de que ambos dispositivos estén en la misma red
4. Configura la URL del servidor en la aplicación móvil

¿Quieres que profundice en algún aspecto específico de esta integración?
