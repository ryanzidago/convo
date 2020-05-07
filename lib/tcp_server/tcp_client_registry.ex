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

  def unregister(room \\ "main-room") do
    Registry.unregister(__MODULE__, room)
  end

  def lookup(room \\ "main-room") do
    Registry.lookup(__MODULE__, room)
  end

  def registered_in(pid) do
    Registry.keys(TcpClientRegistry, pid)
  end

  def broadcast_to_others(message, %{socket: current_client} = state, room \\ "main-room") do
    Registry.dispatch(__MODULE__, room, fn entries ->
      for {pid, socket} <- entries,
          do: if(socket != current_client, do: send(pid, {:msg, socket, message <> "\n"}))
    end)

    state
  end

  def broadcast_to_self(message, %{socket: socket} = state) do
    :gen_tcp.send(socket, message)

    state
  end
end
