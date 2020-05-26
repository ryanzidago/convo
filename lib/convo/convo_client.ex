defmodule Convo.Client do
  @doc """
  This is the Convo.Client, a GenServer representing a client connection to the TCP server (Convo.Server).
  If the Convo.Client dies, it is not restarted, as there is no use to restart a connection that has been left.
  """
  use GenServer, restart: :temporary
  require Logger
  alias Convo.Chat

  @initial_state %{username: nil, socket: nil, pid: nil, room: nil}

  def start_link(socket) do
    Logger.info("Starting Convo.Client ...")
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    Chat.register(socket)
    :gen_tcp.send(socket, "Please, provide your username: ")
    {:ok, %{@initial_state | socket: socket, pid: self(), room: "main-room"}}
  end

  def handle_info({:msg, _socket, _message}, %{username: nil} = state) do
    {:noreply, state}
  end

  def handle_info({:msg, _socket, message}, state) do
    Chat.broadcast_to_self(message, state)
    {:noreply, state}
  end

  def handle_info({:tcp, socket, message}, %{username: nil} = state) do
    :inet.setopts(socket, active: :once)
    :gen_tcp.send(socket, "To display a list of all commands, type `> display-commands`\n")
    {:noreply, %{state | username: String.trim(message)}}
  end

  def handle_info({:tcp, socket, message}, state) do
    :inet.setopts(socket, active: :once)
    Logger.info("Receiving packet #{inspect(message)}")
    state = message |> String.trim() |> Chat.process_message(state)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{username: nil} = state) do
    Process.exit(self(), :shutdown)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{username: username} = state) do
    Chat.broadcast_info_to_others("> #{username} has left the chat!", state)
    Process.exit(self(), :shutdown)
    {:noreply, state}
  end
end
