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

    {:ok, %{username: username}}
  end

  def handle_info({:tcp, socket, message}, %{username: username} = state) do
    message = String.trim(message)

    Logger.info("Incoming packet: #{inspect(message)}")

    broadcast_to_all_clients_except_author(socket, message, state)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    TcpClientPool.delete_client(socket)

    {:noreply, state}
  end

  defp set_username(socket) do
    :gen_tcp.send(socket, "Please, provide your username: ")
    {:ok, username} = :gen_tcp.recv(socket, 0)
    :inet.setopts(socket, active: true)

    String.trim(username)
  end

  defp display_prompt(socket, username) do
    :gen_tcp.send(socket, "\n#{username} : ")
  end

  defp broadcast_to_all_clients_except_author(author, message, %{username: username} = _state) do
    message = "#{username} : #{message}\n"

    TcpClientPool.get_all_clients()
    |> Stream.reject(&(&1 == author))
    |> Enum.each(&broadcast(&1, message))
  end

  defp broadcast(socket, line) do
    :gen_tcp.send(socket, line)
  end
end
