defmodule TcpClient do
  @doc """
  This is the TcpClient, a GenServer whose name is registered under TcpClient.
  If the TcpClient dies, it is not restarted, as there is no use to restart a connection that has been left.

  It's main responsibiliy is to handle interactions with TCP clients, accept and executes commands from clients.
  """
  use GenServer, restart: :temporary

  require Logger

  def start_link(socket) do
    Logger.info("Starting TcpClient ...")

    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    TcpClientRegistry.register(socket)

    username = set_username(socket)

    state = %{
      username: username,
      connected_since: current_date_time(),
      number_of_messages_sent: 0,
      number_of_messages_receveived: 0
    }

    broadcast(socket, ~s(Type: "> display-commands" to display a list of all available commands.))
    broadcast_to_others(socket, "> #{username} has joined the chat!", state, prompt: false)

    {:ok, state}
  end

  def handle_info(
        {:tcp, socket, message},
        %{number_of_messages_receveived: number_of_messages_receveived} = state
      ) do
    state = process_message(socket, message, state)
    {:noreply, %{state | number_of_messages_receveived: number_of_messages_receveived + 1}}
  end

  def handle_info({:tcp_closed, socket}, %{username: username} = state) do
    broadcast_to_others(socket, "> #{username} has left the chat!", state, prompt: false)

    {:noreply, state}
  end

  defp process_message(socket, message, state) do
    message = String.trim(message)

    case message do
      "> display-commands" -> display_commands(socket, state)
      "> change-username " <> new_username -> change_username(socket, new_username, state)
      "> show-stats" -> show_stats(socket, state)
      "> leave" -> leave(socket, state)
      "" -> state
      _ -> broadcast_to_others(socket, message, state)
    end
  end

  defp display_commands(socket, state) do
    message = """

    Here is a list of all the commands that you can execute:

    > display-commands
      # display a list of all commands.

    > change-username <new-username>
      # allows you to change your username; type e.g.: "> change-username bertrand" to change your username to "betrand"

    > show-stats
      # display activity statistics like number of persons connected or time since last login.

    > leave
      # leave the chat and returns to the command line.
    """

    broadcast(socket, message)

    state
  end

  defp change_username(socket, new_username, state) do
    broadcast(socket, "> Your username has been changed to #{new_username}!")

    broadcast_to_others(
      socket,
      "> #{state.username} has changed his/her username to #{new_username}!",
      state,
      prompt: false
    )

    %{state | username: new_username}
  end

  defp show_stats(socket, state) do
    number_of_connected_clients = TcpClientRegistry.lookup() |> length()
    person = if number_of_connected_clients == 1, do: "person", else: "persons"

    message = """

    > Numbers of #{person} currently connected: #{number_of_connected_clients}
    > Last login: #{state.connected_since}
    > Time spent since last login (in minutes): #{
      DateTime.diff(current_date_time(), state.connected_since) |> div(60)
    }
    > Messages sent: #{state.number_of_messages_sent}
    """

    broadcast(socket, message)

    state
  end

  defp leave(socket, %{username: username} = state) do
    broadcast(socket, "See you next time #{username}!")

    send(self(), {:tcp_closed, socket})
    Process.exit(self(), :kill)
    state
  end

  defp set_username(socket) do
    :gen_tcp.send(socket, "Please, provide a username: ")
    {:ok, username} = :gen_tcp.recv(socket, 0)
    :inet.setopts(socket, active: true)

    String.trim(username)
  end

  defp broadcast_to_others(
         current_client,
         message,
         %{username: username, number_of_messages_sent: number_of_messages_sent} = state,
         opts \\ [prompt: true]
       ) do
    message =
      case Keyword.get(opts, :prompt) do
        true -> prompt(username) <> message
        false -> message
      end

    TcpClientRegistry.lookup()
    |> Stream.map(fn {_pid, port} -> port end)
    |> Stream.reject(&(&1 == current_client))
    |> Enum.each(&broadcast(&1, message))

    %{state | number_of_messages_sent: number_of_messages_sent + 1}
  end

  def broadcast(client, message) do
    :gen_tcp.send(client, message <> "\n")
  end

  defp prompt(username) do
    "\r#{username} : "
  end

  defp current_date_time do
    DateTime.utc_now()
    |> DateTime.add(60 * 120, :second)
  end
end
