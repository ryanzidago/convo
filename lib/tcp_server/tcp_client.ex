defmodule TcpClient do
  use GenServer, restart: :temporary

  require Logger

  def start_link(socket) do
    Logger.info("Starting TcpClient ...")

    TcpClientPool.add_client(socket)

    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    {:ok, %{username: set_username(socket)}}
  end

  def handle_info({:tcp, socket, message}, state) do
    state = process_message(socket, message, state)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    TcpClientPool.delete_client(socket)

    {:noreply, state}
  end

  defp process_message(socket, message, state) do
    message = String.trim(message)

    case message do
      "> change-username " <> new_username -> change_username(socket, new_username, state)
      "" -> state
      _ -> broadcast_to_others(socket, message, state)
    end
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

  defp set_username(socket) do
    :gen_tcp.send(socket, "Please, provide a username: ")

    {:ok, username} = :gen_tcp.recv(socket, 0)
    :inet.setopts(socket, active: true)

    String.trim(username)
  end

  defp broadcast_to_others(
         current_client,
         message,
         %{username: username} = state,
         opts \\ [prompt: true]
       ) do
    message =
      case Keyword.get(opts, :prompt) do
        true -> prompt(username) <> message
        false -> message
      end

    TcpClientPool.get_all_clients()
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
