defmodule Convo.Chat do
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
    Logger.debug("Starting Convo.Chat ...")
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
    Registry.keys(__MODULE__, pid)
  end

  def join_room(
        %{pid: pid, socket: socket, username: username, room: new_room} = state,
        previous_room
      )
      when is_binary(new_room) do
    Logger.debug("#{inspect(socket)} registered in #{inspect(registered_in(pid))}")
    unregister(previous_room)
    Logger.debug("#{inspect(socket)} registered in #{inspect(registered_in(pid))}")

    broadcast_to_self("You left room #{previous_room} and joined room #{new_room}!\n", state)

    broadcast_to_others(
      "#{username} left room #{previous_room} and joined room #{new_room}\n",
      state
    )

    Registry.register(__MODULE__, new_room, socket)
    Logger.debug("#{inspect(socket)} registered in #{inspect(registered_in(pid))}")
    state
  end

  def broadcast_to_others(message, %{socket: current_client, room: room} = state) do
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
