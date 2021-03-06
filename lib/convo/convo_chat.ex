defmodule Convo.Chat do
  @doc """
  This is the Convo.Chat.

  It's main responsibility is to handle interactions with TCP clients, accept and executes commands from clients.
  It uses Elixir's Registry as a PubSub mechanism to dispatch message to the proper TCP client
  registered in the correct rooms.
  """
  require Logger

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link do
    Logger.debug("Starting Convo.Chat ...")

    opts = [
      keys: :duplicate,
      name: __MODULE__,
      partitions: System.schedulers_online(),
      parallel: true
    ]

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

  def select_all do
    Registry.select(__MODULE__, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
  end

  def process_message("", state) do
    state
  end

  def process_message(message, %{username: username, room: previous_room} = state) do
    case message do
      "> display-commands" ->
        display_commands(state)

      "> change-username " <> new_username ->
        change_username(%{state | username: new_username}, username)

      "> join-room " <> room ->
        join_room(%{state | room: room}, previous_room)

      "> leave" ->
        leave(state)

      _ ->
        broadcast_to_others(prompt(username) <> message, state)
    end
  end

  def join_room(
        %{socket: socket, username: username, room: new_room} = state,
        previous_room
      )
      when is_binary(new_room) do
    unregister(previous_room)

    Registry.register(__MODULE__, new_room, socket)

    broadcast_to_self("You left room #{previous_room} and joined room #{new_room}!\n", state)

    broadcast_info_to_others(
      "#{username} left room #{previous_room} and joined room #{new_room}",
      state
    )

    state
  end

  def broadcast_info_to_others(message, %{socket: current_client} = _state) do
    select_all()
    |> Stream.filter(fn {_room, _pid, socket} -> socket != current_client end)
    |> Enum.each(fn {_room, _pid, socket} -> broadcast(message <> "\n", socket) end)
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

  def broadcast(message, socket) do
    :gen_tcp.send(socket, message)
  end

  defp display_commands(state) do
    message = """

    Here is a list of all the commands that you can execute:

    > display-commands
      # display a list of all commands.

    > change-username <new username>
      # allows you to change your username; type e.g.: "> change-username bertrand" to change your username to "betrand".

    > join-room <name of the room>
      # join an existing room, or automatically create a new room if it did not exist.

    > leave
      # leave the chat and returns to the command line.
    """

    broadcast_to_self(message, state)
  end

  defp change_username(%{username: new_username} = state, previous_username) do
    broadcast_to_self(
      "> Your username has been changed to #{new_username}!",
      state
    )

    broadcast_to_others(
      "> #{previous_username} changed his/her username to #{new_username}!",
      state
    )
  end

  defp leave(%{pid: pid, username: username, socket: socket} = state) do
    broadcast_to_self("See you next time #{username}!", state)

    send(pid, {:tcp_closed, socket})
    state
  end

  defp prompt(username) do
    "\r#{username} : "
  end
end
