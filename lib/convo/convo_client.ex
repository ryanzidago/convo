defmodule Convo.Client do
  @doc """
  This is the ConvoClient, a GenServer whose name is registered under ConvoClient.
  If the ConvoClient dies, it is not restarted, as there is no use to restart a connection that has been left.

  It's main responsibility is to handle interactions with TCP clients, accept and executes commands from clients.
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

  def handle_info({:tcp, _socket, message}, %{username: nil} = state) do
    {:noreply, %{state | username: String.trim(message)}}
  end

  def handle_info({:tcp, _socket, message}, state) do
    Logger.info("Receiving packet #{inspect(message)}")
    state = message |> String.trim() |> Chat.process_message(state)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{username: nil} = state) do
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{username: username} = state) do
    Chat.broadcast_to_others("> #{username} has left the chat!", state)
    Chat.unregister()
    {:noreply, state}
  end
end