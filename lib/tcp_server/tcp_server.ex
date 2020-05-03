defmodule TcpServer do
  @doc """
  The TCP server is a task named TcpServer. If the TCP server dies, it is automatically restarted.

  It's main responsibiliy is to listen a socket on port 5000 and accept clients connections.
  """

  use Task, restart: :permanent
  require Logger

  def start_link(port) do
    Logger.info("Starting TcpServer running in pid #{inspect(self())}...")

    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
    Process.register(self(), TcpServer)

    {:ok, listen_socket} =
      :gen_tcp.listen(port, [
        :binary,
        packet: :line,
        active: false,
        reuseaddr: true
      ])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(listen_socket)
  end

  defp loop_acceptor(listen_socket) do
    {:ok, client} = :gen_tcp.accept(listen_socket)

    Logger.info(
      "Client #{inspect(client)} from listen_socket #{inspect(listen_socket)} connected to TcpServer"
    )

    {:ok, pid} = DynamicSupervisor.start_child(TcpServer.DynamicSupervisor, {TcpClient, client})
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(listen_socket)
  end
end
