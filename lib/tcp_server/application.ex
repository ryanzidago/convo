defmodule TcpServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # :observer.start()

    children = [
      # Starts a worker by calling: TcpServer.Worker.start_link(arg)
      # {TcpServer.Worker, arg}

      # starting a Task.Supervisor process with the name TcpServer.TaskSupervisor
      {Task.Supervisor, name: TcpServer.TaskSupervisor},
      {Task, fn -> TcpServer.accept(port_config()) end}
    ]

    # starting a Supervisor process with the name TcpServer.Supervisor
    opts = [strategy: :one_for_one, name: TcpServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port_config do
    _port =
      (System.get_env("PORT") || "9000")
      |> String.to_integer()
  end
end
