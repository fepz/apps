INPUT:

Crea una aplicación Elixir de nombre HttpHello que al recibir un request GET de la forma IP:PORT/hello/name responda con "Hello, name" (en texto plano) reemplazando name por el nombre indicado.

---

Claude responde con:

Voy a crear una aplicación en Elixir llamada HttpHello que responda a peticiones GET con un saludo personalizado.

```elixir
defmodule HttpHello do
  use Application

  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: HttpHello.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: HttpHello.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

    defmodule HttpHello.Router do
    use Plug.Router

    plug :match
    plug :dispatch

    get "/hello/:name" do
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "Hello, #{name}")
    end

    match _ do
        send_resp(conn, 404, "Not found")
    end
    end

```

Para usar esta aplicación, necesitarás crear un proyecto Elixir con las dependencias adecuadas. Aquí te muestro los pasos para configurar y ejecutar la aplicación:

1. Crea un nuevo proyecto Elixir:
```bash
mix new http_hello --sup
cd http_hello
```

2. Agrega las dependencias necesarias en el archivo `mix.exs`:
```elixir
defp deps do
  [
    {:plug_cowboy, "~> 2.5"}
  ]
end
```

3. Instala las dependencias:
```bash
mix deps.get
```

4. Copia el código de la aplicación en los siguientes archivos:
   - Crea `lib/http_hello.ex` con el código del módulo `HttpHello`
   - Crea `lib/http_hello/router.ex` con el código del módulo `HttpHello.Router`

5. Asegúrate de actualizar el archivo `mix.exs` para incluir la aplicación como punto de entrada:
```elixir
def application do
  [
    extra_applications: [:logger],
    mod: {HttpHello, []}
  ]
end
```

6. Inicia la aplicación:
```bash
mix run --no-halt
```

Una vez ejecutada, la aplicación estará disponible en `http://localhost:4000/hello/name`, donde puedes reemplazar "name" con cualquier nombre y recibirás la respuesta "Hello, nombre_ingresado" en texto plano.
