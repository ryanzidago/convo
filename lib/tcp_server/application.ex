defmodule TcpServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: TcpServer.Worker.start_link(arg)
      # {TcpServer.Worker, arg}
      {Task, fn -> TcpServer.accept(port_config()) end}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TcpServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port_config do
    _port =
      (System.get_env("PORT") || "9000")
      |> String.to_integer()
  end
end
