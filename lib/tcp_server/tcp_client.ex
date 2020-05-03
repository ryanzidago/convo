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

  def handle_info({:tcp, _socket, "> change-username: " <> new_username}, state) do
    {:noreply, %{state | username: String.trim(new_username)}}
  end

  def handle_info({:tcp, socket, message}, %{username: username} = state) do
    broadcast_to_others(socket, String.trim(message), username)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    TcpClientPool.delete_client(socket)

    {:noreply, state}
  end

  defp set_username(socket) do
    :gen_tcp.send(socket, "Please, provide a username: ")

    {:ok, username} = :gen_tcp.recv(socket, 0)
    :inet.setopts(socket, active: true)

    String.trim(username)
  end

  defp broadcast_to_others(current_client, message, username) do
    TcpClientPool.get_all_clients()
    |> Stream.reject(&(&1 == current_client))
    |> Enum.each(&broadcast(&1, prompt(username) <> message <> "\n"))
  end

  def broadcast(client, message) do
    :gen_tcp.send(client, message)
  end

  defp prompt(username) do
    "\r#{username} : "
  end
end
