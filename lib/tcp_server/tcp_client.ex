defmodule TcpClient do
  @doc """
  This is the TcpClient, a GenServer whose name is registered under TcpClient.
  If the TcpClient dies, it is not restarted, as there is no use to restart a connection that has been left.

  It's main responsibility is to handle interactions with TCP clients, accept and executes commands from clients.
  """
  use GenServer, restart: :temporary
  require Logger

  @initial_state %{username: nil, socket: nil, pid: nil, room: nil}

  def start_link(socket) do
    Logger.info("Starting TcpClient ...")
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    Chat.register(socket)
    :gen_tcp.send(socket, "Please, provide your username: ")
    {:ok, %{@initial_state | socket: socket, pid: self(), room: "main-room"}}
  end

  def handle_info({:msg, _socket, _message}, %{username: nil} = state) do
    {:noreply, state}
  end

  def handle_info({:msg, _socket, message}, state) do
    Chat.broadcast_to_self(message, state)
    {:noreply, state}
  end

  def handle_info({:tcp, _socket, message}, %{username: nil} = state) do
    {:noreply, %{state | username: String.trim(message)}}
  end

  def handle_info({:tcp, _socket, message}, state) do
    Logger.info("Receiving packet #{inspect(message)}")
    state = message |> String.trim() |> process_message(state)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{username: nil} = state) do
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{username: username} = state) do
    Chat.broadcast_to_others("> #{username} has left the chat!", state)
    Chat.unregister()
    {:noreply, state}
  end

  defp process_message(message, %{username: username, room: previous_room} = state) do
    case message do
      "> display-commands" -> display_commands(state)
      "> change-username " <> new_username -> change_username(new_username, state)
      "> join-room " <> new_room -> Chat.join_room(%{state | room: new_room}, previous_room)
      "> leave" -> leave(state)
      "" -> state
      _ -> Chat.broadcast_to_others(prompt(username) <> message, state)
    end
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

    Chat.broadcast_to_self(message, state)
  end

  defp change_username(new_username, %{username: old_username} = state) do
    Chat.broadcast_to_self(
      "> Your username has been changed to #{new_username}!",
      state
    )

    Chat.broadcast_to_others(
      "> #{old_username} changed his/her username to #{new_username}!",
      state
    )

    %{state | username: new_username}
  end

  defp leave(%{username: username} = state) do
    Chat.broadcast_to_self("See you next time #{username}!", state)
    Chat.broadcast_to_others("> #{username} has left the chat!", state)
    Chat.unregister()

    Process.exit(self(), :kill)
    state
  end

  defp prompt(username) do
    "\r#{username} : "
  end
end
