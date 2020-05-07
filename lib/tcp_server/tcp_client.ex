defmodule TcpClient do
  @doc """
  This is the TcpClient, a GenServer whose name is registered under TcpClient.
  If the TcpClient dies, it is not restarted, as there is no use to restart a connection that has been left.

  It's main responsibility is to handle interactions with TCP clients, accept and executes commands from clients.
  """
  use GenServer, restart: :temporary

  require Logger

  @initial_state %{username: nil, socket: nil}

  def start_link(socket) do
    Logger.info("Starting TcpClient ...")
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    TcpClientRegistry.register(socket)
    :gen_tcp.send(socket, "Please, provide your username: ")
    {:ok, %{@initial_state | socket: socket}}
  end

  def handle_info({:tcp, _socket, message}, state) do
    state = process_message(String.trim(message), state)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{username: nil} = state) do
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{username: username} = state) do
    broadcast_to_others("> #{username} has left the chat!", state, prompt: false)
    {:noreply, state}
  end

  defp process_message(username, %{username: nil} = state) do
    %{state | username: username}
  end

  defp process_message(message, state) do
    case message do
      "> display-commands" -> display_commands(state)
      "> change-username " <> new_username -> change_username(new_username, state)
      "> leave" -> leave(state)
      "" -> state
      _ -> broadcast_to_others(message, state)
    end
  end

  defp display_commands(%{socket: socket} = state) do
    message = """

    Here is a list of all the commands that you can execute:

    > display-commands
      # display a list of all commands.

    > change-username <new-username>
      # allows you to change your username; type e.g.: "> change-username bertrand" to change your username to "betrand"

    > leave
      # leave the chat and returns to the command line.
    """

    broadcast(socket, message)

    state
  end

  defp change_username(new_username, %{socket: socket, username: username} = state) do
    broadcast(socket, "> Your username has been changed to #{new_username}!")

    broadcast_to_others(
      "> #{username} has changed his/her username to #{new_username}!",
      state,
      prompt: false
    )

    %{state | username: new_username}
  end

  defp leave(%{username: username, socket: socket} = state) do
    broadcast(socket, "See you next time #{username}!")

    send(self(), {:tcp_closed, socket})
    Process.exit(self(), :kill)
    state
  end

  defp broadcast_to_others(
         message,
         %{username: username, socket: current_client} = state,
         opts \\ [prompt: true]
       ) do
    message =
      case Keyword.get(opts, :prompt) do
        true -> prompt(username) <> message
        false -> message
      end

    TcpClientRegistry.lookup()
    |> Stream.map(fn {_pid, socket} -> socket end)
    |> Stream.reject(&(&1 == current_client))
    |> Enum.each(&broadcast(&1, message))

    state
  end

  def broadcast(client, message) do
    :gen_tcp.send(client, message <> "\n")
  end

  defp prompt(username) do
    "\r#{username} : "
  end
end
