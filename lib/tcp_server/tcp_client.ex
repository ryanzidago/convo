defmodule TcpClient do
  use GenServer, restart: :temporary

  require Logger

  def start_link(socket) do
    Logger.info("Starting TcpClient running on pid #{inspect(self())}")

    TcpClientPool.add_client(socket)

    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    username = set_username(socket)

    {:ok, %{socket: socket, username: username}}
  end

  def handle_info({:tcp, socket, data}, %{username: username} = state) do
    Logger.info("incoming packet: #{inspect(data)}")
    display_prompt(socket, username)
    broadcast_to_all_clients_except_author(socket, data)

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

    username
  end

  defp display_prompt(socket, username) do
    :gen_tcp.send(socket, "#{String.trim(username)}: ")
  end

  defp broadcast_to_all_clients_except_author(author, data) do
    TcpClientPool.get_all_clients()
    |> Stream.reject(&(&1 == author))
    |> Enum.each(&broadcast(&1, data))
  end

  defp broadcast(socket, line) do
    :gen_tcp.send(socket, line)
  end
end
