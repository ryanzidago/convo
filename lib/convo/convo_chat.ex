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

    broadcast_to_others(
      "#{username} left room #{previous_room} and joined room #{new_room}\n",
      state
    )
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

  defp display_commands(state) do
    message = """

    Here is a list of all the commands that you can execute:

    > display-commands
      # display a list of all commands.

    > change-username <new-username>
      # allows you to change your username; type e.g.: "> change-username bertrand" to change your username to "betrand"

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

  defp leave(%{username: username} = state) do
    broadcast_to_self("See you next time #{username}!", state)
    broadcast_to_others("> #{username} has left the chat!", state)
    unregister()

    Process.exit(self(), :kill)
    state
  end

  defp prompt(username) do
    "\r#{username} : "
  end
end
