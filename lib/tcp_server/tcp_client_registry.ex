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
    Logger.debug("Starting TcpClientRegistry ...")
    opts = [keys: :duplicate, name: __MODULE__, partitions: System.schedulers_online()]
    Registry.start_link(opts)
  end

  def register(socket, room \\ "main-room") when is_binary(room) do
    Registry.register(__MODULE__, room, socket)
  end

  def unregister(socket, room \\ "main-room") do
    Registry.unregister(__MODULE__, room)
  end

  def lookup(room \\ "main-room") do
    Registry.lookup(__MODULE__, room)
  end

  def registered_in(pid) do
    Registry.keys(TcpClientRegistry, pid)
  end

  # def dispatch do
  #   Registry.dispatch(__MODULE__, "main-room", fn entries ->
  #     Logger.debug("Registry entry: #{inspect(entries)}")
  #     for {_pid, socket} <- entries, do: :gen_tcp.send(socket, "Hello from the REGISTRY!")
  #   end)
  # end
end
