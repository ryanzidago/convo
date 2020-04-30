defmodule TcpServer do
  use Task
  require Logger

  def start_link(port) do
    Logger.info("Starting TcpServer ...")

    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
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

    TcpClientPool.add_client(client)

    {:ok, pid} = Task.Supervisor.start_child(TcpServer.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(listen_socket)
  end

  defp serve(socket) do
    msg =
      case read_line(socket) do
        {:ok, msg} ->
          msg

        {:error, :closed} ->
          Logger.info("Client left!")

          TcpClientPool.delete_client(socket)

          exit(:shutdown)
      end

    display_message(msg, socket)

    author = socket
    broadcast_to_all_clients_except_author(author, msg)

    serve(socket)
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, line) do
    :gen_tcp.send(socket, line)
  end

  defp broadcast_to_all_clients_except_author(author, msg) do
    TcpClientPool.get_all_clients()
    |> Stream.reject(&(&1 == author))
    |> Enum.each(&write_line(&1, msg))
  end

  defp display_message("\n", _socket), do: nil
  defp display_message("\r\n", _socket), do: nil

  defp display_message(msg, socket) do
    Logger.info(
      "Received message from client #{inspect(socket)} running in pid #{inspect(self())}: #{msg}"
    )
  end
end
