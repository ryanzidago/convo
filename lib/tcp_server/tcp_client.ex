defmodule TcpClient do
  use GenServer, restart: :temporary

  require Logger

  def start_link(socket) do
    Logger.info("Starting TcpClient ...")

    TcpClientPool.add_client(socket)

    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    username = set_username(socket)

    state = %{username: username}

    message = "#{username} has joined the chat!\n"
    broadcast_info_message_to_others(socket, message)

    {:ok, state}
  end

  def handle_info(
        {:tcp, socket, "> change-username: " <> new_username},
        %{username: username} = state
      ) do
    new_username = String.trim(new_username)

    broadcast_info_message_to_self(
      socket,
      "Your username has been changed from #{username} to #{new_username}\n"
    )

    message = "#{username} has changed his/her username to #{new_username}!"
    broadcast_info_message_to_others(socket, message)

    {:noreply, %{state | username: new_username}}
  end

  def handle_info({:tcp, socket, message}, state) do
    message = String.trim(message)
    broadcast_to_others(socket, message, state)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    TcpClientPool.delete_client(socket)

    {:noreply, state}
  end

  defp set_username(socket) do
    broadcast_info_message_to_self(socket, "Please, provide a username: ")

    {:ok, username} = :gen_tcp.recv(socket, 0)
    :inet.setopts(socket, active: true)

    String.trim(username)
  end

  defp broadcast_info_message_to_self(author, message) do
    :gen_tcp.send(author, message)
  end

  defp broadcast_info_message_to_others(author, message) do
    broadcast(author, message)
  end

  defp broadcast_to_others(author, message, %{username: username} = _state) do
    message = "#{username} : #{message}\n"

    broadcast(author, message)
  end

  defp broadcast(author, message) do
    TcpClientPool.get_all_clients()
    |> Stream.reject(&(&1 == author))
    |> Enum.each(&:gen_tcp.send(&1, message))
  end
end
