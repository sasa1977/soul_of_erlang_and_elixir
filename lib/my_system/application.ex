defmodule MySystem.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MySystem.LoadControl,
      MySystemWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:my_system, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MySystem.PubSub},
      # Start a worker by calling: MySystem.Worker.start_link(arg)
      # {MySystem.Worker, arg},
      # Start to serve requests, typically the last entry
      MySystemWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MySystem.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MySystemWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
