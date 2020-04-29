defmodule TcpServer do
  use Task
  require Logger

  def start_link(port) do
    Logger.info("Starting TcpServer ...")

    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [
        :binary,
        packet: :line,
        active: false,
        reuseaddr: true
      ])

    Logger.info("Accepting connections on port #{port}")

    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Logger.info("client #{inspect(client)} from socket #{inspect(socket)} connected to TcpServer")

    TcpClientPool.add_client(client)

    {:ok, pid} = Task.Supervisor.start_child(TcpServer.TaskSupervisor, fn -> serve(client) end)

    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp serve(socket) do
    msg =
      case read_line(socket) do
        {:ok, msg} ->
          msg

        {:error, :closed} ->
          Logger.info("client left!")

          TcpClientPool.delete_client(socket)

          exit(:shutdown)
      end

    String.trim_trailing(msg)
    |> IO.inspect(
      label: "received msg from client #{inspect(socket)} running in pid #{inspect(self())}"
    )

    author = socket

    TcpClientPool.get_all_clients()
    |> Stream.reject(&(&1 == author))
    |> Enum.each(&write_line(&1, msg))

    serve(socket)
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, line) do
    :gen_tcp.send(socket, line)
  end
end
