defmodule KvServerWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      KvServerWebWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:kv_server_web, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: KvServerWeb.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: KvServerWeb.Finch},
      # Start a worker by calling: KvServerWeb.Worker.start_link(arg)
      # {KvServerWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      KvServerWebWeb.Endpoint,
      KvWeb.KvStore
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KvServerWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KvServerWebWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
