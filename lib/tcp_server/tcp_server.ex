defmodule TcpServer do
  require Logger

  def start_link(port) do
    Logger.info("Starting TcpServer ...")

    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")

    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Logger.info("client #{inspect(client)} from socket #{inspect(socket)} connected to TcpServer")

    {:ok, pid} = Task.Supervisor.start_child(TcpServer.TaskSupervisor, fn -> serve(client) end)

    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp serve(socket) do
    msg =
      case read_line(socket) do
        {:ok, msg} ->
          String.trim_trailing(msg)

        {:error, :closed} ->
          Logger.info("client left!")
          exit(:shutdown)
      end

    IO.inspect(msg, label: "msg")
    write_line(socket, msg)
    serve(socket)
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, line) do
    :gen_tcp.send(socket, line)
  end
end
