defmodule Convo.Server do
  @doc """
  The TCP server is a task named Convo. If the TCP server dies, it is automatically restarted.

  It's main responsibiliy is to listen a socket on port 5000 and accept clients connections.
  For each one of those client connections, the DynamicSupervisor Convo.DynamicSupervisor
  passes the socket representing the client connection to the ConvoClient GenServer.
  """

  use Task, restart: :permanent
  require Logger

  def start_link(port) do
    Logger.info("Starting Convo.Server running in pid #{inspect(self())}...")

    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
    Process.register(self(), Convo.Server)

    {:ok, listen_socket} =
      :gen_tcp.listen(port, [
        :binary,
        packet: :line,
        active: :once,
        reuseaddr: true
      ])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(listen_socket)
  end

  defp loop_acceptor(listen_socket) do
    {:ok, client} = :gen_tcp.accept(listen_socket)

    Logger.info(
      "Convo.Client #{inspect(client)} from listen_socket #{inspect(listen_socket)} connected to Convo.Server"
    )

    {:ok, pid} = DynamicSupervisor.start_child(Convo.DynamicSupervisor, {Convo.Client, client})
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(listen_socket)
  end
end
