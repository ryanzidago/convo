defmodule Convo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Convo.Worker.start_link(arg)
      # {Convo.Worker, arg}
      {DynamicSupervisor, strategy: :one_for_one, name: Convo.DynamicSupervisor},
      {Convo.Chat, []},
      {Convo.Server, 5000}
    ]

    # starting a Supervisor process with the name Convo.Supervisor
    opts = [strategy: :one_for_one, name: Convo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
