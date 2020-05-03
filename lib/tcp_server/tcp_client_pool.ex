defmodule TcpClientPool do
  @doc """
  This is the TcpClientPool, an Agent whose sole responsibiliy is to add/deletes clients to the pool of clients.
  If the TcpClientPool dies, it is automatically restarted.

  This pool of clients is mostly used to broadcast messages to all of the current connected clients.
  """
  use Agent

  require Logger

  def start_link(_) do
    Logger.info("Starting TcpClientPool...")

    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def add_client(client) do
    Logger.info(
      "Adding client #{inspect(client)} to client pool running in pid #{inspect(self())}"
    )

    Agent.update(__MODULE__, fn clients -> [client | clients] end)
  end

  def get_all_clients do
    Agent.get(__MODULE__, fn clients -> clients end)
  end

  def delete_client(client) do
    Logger.info(
      "Deleting client #{inspect(client)} from client pool running in pid #{inspect(self())}"
    )

    Agent.update(__MODULE__, fn clients ->
      List.delete(clients, client)
    end)
  end
end
