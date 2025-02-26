Voy a crear una aplicación de mensajería en Elixir con una interfaz en MIT App Inventor. Primero, diseñaré el servidor en Elixir y luego la interfaz móvil.

```elixir
defmodule ChatServer do
  use GenServer

  # API del cliente
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def register_user(server, username) do
    GenServer.call(server, {:register, username})
  end

  def unregister_user(server, username) do
    GenServer.call(server, {:unregister, username})
  end

  def send_message(server, from_user, to_user, message) do
    if String.length(message) <= 256 do
      GenServer.call(server, {:send_message, from_user, to_user, message})
    else
      {:error, "El mensaje excede el límite de 256 caracteres"}
    end
  end

  def get_connected_users(server) do
    GenServer.call(server, :get_users)
  end

  # Callbacks del GenServer
  @impl true
  def init(:ok) do
    # Estado inicial: mapa de usuarios y sus procesos PID
    {:ok, %{users: %{}}}
  end

  @impl true
  def handle_call({:register, username}, {pid, _}, state) do
    if Map.has_key?(state.users, username) do
      {:reply, {:error, "Nombre de usuario ya en uso"}, state}
    else
      # Monitoreamos el proceso para detectar desconexiones
      Process.monitor(pid)
      new_users = Map.put(state.users, username, pid)
      {:reply, {:ok, username}, %{state | users: new_users}}
    end
  end

  @impl true
  def handle_call({:unregister, username}, _from, state) do
    new_users = Map.delete(state.users, username)
    {:reply, :ok, %{state | users: new_users}}
  end

  @impl true
  def handle_call({:send_message, from_user, to_user, message}, _from, state) do
    case Map.fetch(state.users, to_user) do
      {:ok, to_pid} ->
        # Enviamos un mensaje al proceso del usuario destinatario
        send(to_pid, {:chat_message, from_user, message})
        {:reply, :ok, state}
      :error ->
        {:reply, {:error, "Usuario destino no encontrado"}, state}
    end
  end

  @impl true
  def handle_call(:get_users, _from, state) do
    users_list = Map.keys(state.users)
    {:reply, users_list, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Cuando un proceso se cierra, eliminamos al usuario correspondiente
    {username, new_users} =
      Enum.find_value(state.users, {nil, state.users}, fn {username, user_pid} ->
        if user_pid == pid, do: {username, Map.delete(state.users, username)}, else: nil
      end)

    if username do
      {:noreply, %{state | users: new_users}}
    else
      {:noreply, state}
    end
  end
end

```

```elixir
defmodule ChatApp do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Inicia el servidor de chat con un nombre registrado
      {ChatServer, name: ChatServer},
      # Configuración del servidor web para API REST
      {Plug.Cowboy, scheme: :http, plug: ChatApi, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: ChatApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule ChatApi do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  # Endpoint para registro de usuarios
  post "/register" do
    %{"username" => username} = conn.body_params

    case ChatServer.register_user(ChatServer, username) do
      {:ok, _} ->
        send_resp(conn, 200, Jason.encode!(%{status: "ok", message: "Usuario registrado"}))
      {:error, reason} ->
        send_resp(conn, 400, Jason.encode!(%{status: "error", message: reason}))
    end
  end

  # Endpoint para cerrar sesión
  post "/logout" do
    %{"username" => username} = conn.body_params
    ChatServer.unregister_user(ChatServer, username)
    send_resp(conn, 200, Jason.encode!(%{status: "ok", message: "Sesión cerrada"}))
  end

  # Endpoint para enviar mensajes
  post "/send" do
    %{"from" => from_user, "to" => to_user, "message" => message} = conn.body_params

    case ChatServer.send_message(ChatServer, from_user, to_user, message) do
      :ok ->
        send_resp(conn, 200, Jason.encode!(%{status: "ok", message: "Mensaje enviado"}))
      {:error, reason} ->
        send_resp(conn, 400, Jason.encode!(%{status: "error", message: reason}))
    end
  end

  # Endpoint para obtener la lista de usuarios conectados
  get "/users" do
    users = ChatServer.get_connected_users(ChatServer)
    send_resp(conn, 200, Jason.encode!(%{users: users}))
  end

  # Endpoint para recibir mensajes (polling)
  get "/messages/:username" do
    username = conn.path_params["username"]

    # Espera hasta 30 segundos para recibir mensajes (long polling)
    receive do
      {:chat_message, from_user, content} ->
        send_resp(conn, 200, Jason.encode!(%{from: from_user, message: content}))
    after
      30_000 -> # 30 segundos timeout
        send_resp(conn, 204, "") # No content
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end

```

```elixir
defmodule ChatApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ChatApp, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"}
    ]
  end
end

```

Para la interfaz de usuario en MIT App Inventor, voy a diseñar una aplicación móvil que se conecte al servidor Elixir. A continuación, muestro cómo sería el diseño y los bloques de código para la aplicación:



# Diseño de la Aplicación en MIT App Inventor

## Componentes necesarios:

### Pantalla 1: Login
- **Etiqueta**: Título "Chat App"
- **CampoDeTexto**: Para introducir nombre de usuario
- **Botón**: Para conectarse al servidor
- **Web**: Componente para comunicación HTTP con el servidor

### Pantalla 2: Chat
- **ListaSelección**: Muestra los usuarios conectados
- **CampoDeTexto**: Para escribir mensajes
- **Botón**: Para enviar mensajes
- **ListaVisual**: Para mostrar los mensajes recibidos
- **Reloj**: Para consultar periódicamente si hay nuevos mensajes
- **Web**: Componente para comunicación HTTP con el servidor
- **Notificador**: Para mostrar mensajes de error o confirmación

## Estructura de pantallas:

1. **Pantalla de Login**:
   - Diseño sencillo con logo en la parte superior
   - Campo de texto para el nombre de usuario
   - Botón de "Conectar" en la parte inferior

2. **Pantalla de Chat**:
   - Panel superior con la lista de usuarios conectados
   - Panel central con los mensajes recibidos
   - Panel inferior con campo de texto y botón para enviar mensajes
   - Botón de "Cerrar sesión" en la esquina superior derecha




# Bloques de código para MIT App Inventor

## Variables globales
- `ServidorURL`: URL base del servidor (por ejemplo, "http://tu-servidor-elixir:4000")
- `UsuarioActual`: Nombre del usuario conectado

## Pantalla de Login

### Al inicializar
```blocks
cuando Pantalla1.Inicializar
  establecer ServidorURL como "http://tu-servidor-elixir:4000"
```

### Botón Conectar
```blocks
cuando BtnConectar.Clic
  si TxtUsuario.Texto es igual a ""
    entonces
      llamar Notificador.MostrarAlerta con mensaje "Introduce un nombre de usuario"
    si no
      llamar Web1.PostText con url unir(ServidorURL, "/register"),
                            texto unir("username=", TxtUsuario.Texto)
```

### Respuesta del servidor para registro
```blocks
cuando Web1.GotText
  definir respuesta como JsonTextDecode(responseContent)
  si respuesta get "status" es igual a "ok"
    entonces
      establecer UsuarioActual como TxtUsuario.Texto
      abrir otra pantalla nombrePantalla "Pantalla2"
    si no
      llamar Notificador.MostrarAlerta con mensaje obtener respuesta get "message"
```

## Pantalla de Chat

### Al inicializar
```blocks
cuando Pantalla2.Inicializar
  llamar ActualizarUsuarios
  establecer Reloj1.TimerInterval como 5000
  establecer Reloj1.TimerEnabled como verdadero
```

### Actualizar lista de usuarios
```blocks
para ActualizarUsuarios
  llamar Web2.Get con url unir(ServidorURL, "/users")
```

### Respuesta del servidor para lista de usuarios
```blocks
cuando Web2.GotText
  definir respuesta como JsonTextDecode(responseContent)
  definir listaUsuarios como obtener respuesta get "users"
  limpiar ListaUsuarios.Elementos
  para cada usuario de listaUsuarios
    si no (usuario es igual a UsuarioActual)
      entonces
        añadir usuario a ListaUsuarios.Elementos
```

### Botón Enviar Mensaje
```blocks
cuando BtnEnviar.Clic
  si ListaUsuarios.Selección es igual a ""
    entonces
      llamar Notificador.MostrarAlerta con mensaje "Selecciona un destinatario"
    si no
      si TxtMensaje.Texto es igual a ""
        entonces
          llamar Notificador.MostrarAlerta con mensaje "Escribe un mensaje"
        si no
          definir datos como crear diccionario
          poner "from" como UsuarioActual en datos
          poner "to" como ListaUsuarios.Selección en datos
          poner "message" como TxtMensaje.Texto en datos
          llamar Web2.PostText con url unir(ServidorURL, "/send"),
                                texto JsonTextEncode(datos)
          establecer TxtMensaje.Texto como ""
```

### Consultar mensajes nuevos
```blocks
cuando Reloj1.Timer
  llamar Web2.Get con url unir(unir(ServidorURL, "/messages/"), UsuarioActual)
  llamar ActualizarUsuarios
```

### Recibir mensajes nuevos
```blocks
cuando Web2.GotText para mensajes
  si responseCode es igual a 200
    entonces
      definir respuesta como JsonTextDecode(responseContent)
      definir mensaje como crear lista
      añadir unir("De: ", obtener respuesta get "from") a mensaje
      añadir obtener respuesta get "message" a mensaje
      añadir mensaje a ListaMensajes.Elementos
```

### Botón Cerrar Sesión
```blocks
cuando BtnCerrarSesion.Clic
  definir datos como crear diccionario
  poner "username" como UsuarioActual en datos
  llamar Web2.PostText con url unir(ServidorURL, "/logout"),
                          texto JsonTextEncode(datos)
  establecer Reloj1.TimerEnabled como falso
  cerrar pantalla
```


## Explicación del Sistema

Este sistema consta de dos partes principales:

### 1. Servidor Elixir:
- Utiliza `GenServer` para mantener el estado de los usuarios conectados.
- Proporciona una API REST usando Plug y Cowboy para comunicación con clientes.
- Funcionalidades principales:
  - Registro y desconexión de usuarios
  - Envío de mensajes entre usuarios
  - Consulta de usuarios conectados
  - Recepción de mensajes mediante long polling

### 2. Aplicación Móvil (MIT App Inventor):
- Dos pantallas: login y chat
- Funcionalidades:
  - Conexión con nombre de usuario
  - Visualización de usuarios conectados
  - Envío y recepción de mensajes
  - Actualización automática de la lista de usuarios

## Cómo ejecutar el proyecto

1. **Servidor Elixir**:
   - Crea un nuevo proyecto: `mix new chat_app`
   - Reemplaza los archivos con el código proporcionado
   - Instala dependencias: `mix deps.get`
   - Ejecuta el servidor: `mix run --no-halt`

2. **Aplicación móvil**:
   - Abre MIT App Inventor (https://appinventor.mit.edu/)
   - Crea un nuevo proyecto
   - Diseña las pantallas según las instrucciones
   - Implementa los bloques de código
   - Ajusta la URL del servidor en la variable global
   - Prueba la aplicación en un dispositivo o emulador

¿Necesitas más detalles sobre alguna parte específica del proyecto?
