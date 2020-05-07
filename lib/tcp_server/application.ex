defmodule TcpServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: TcpServer.Worker.start_link(arg)
      # {TcpServer.Worker, arg}
      {DynamicSupervisor, strategy: :one_for_one, name: TcpServer.DynamicSupervisor},
      TcpClientRegistry,
      {TcpServer, 5000}
    ]

    # starting a Supervisor process with the name TcpServer.Supervisor
    opts = [strategy: :one_for_one, name: TcpServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
