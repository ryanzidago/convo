defmodule TcpClientRegistry do
  require Logger

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :temporary,
      shutdown: 500
    }
  end

  def start_link do
    Logger.debug("STARTING REGISTRY ...")
    opts = [keys: :duplicate, name: __MODULE__, partitions: System.schedulers_online()]
    Registry.start_link(opts)
  end

  def register(socket) do
    Registry.register(__MODULE__, "main-room", socket)
  end

  def lookup do
    Registry.lookup(__MODULE__, "main-room")
  end

  def dispatch do
    Registry.dispatch(__MODULE__, "main-room", fn entries ->
      Logger.debug("Registry entry: #{inspect(entries)}")
      for {pid, socket} <- entries, do: send(pid, {:broadcast, socket, "Hello from Registry!"})
    end)
  end
end
