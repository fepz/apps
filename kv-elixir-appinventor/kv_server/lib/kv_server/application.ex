defmodule KvServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @port 8888

  @impl true
  def start(_type, _args) do
    children = [
      # inicia la bd key-value
      KvServer.KvStore,
      # inicia el webserver
      {Plug.Cowboy, scheme: :http, plug: KvServer.Api, options: [port: @port]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KvServer.Supervisor]

    IO.puts("Servidor KV en http://localhost:#{@port}")

    Supervisor.start_link(children, opts)
  end
end
