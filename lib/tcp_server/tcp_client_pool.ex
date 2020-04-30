defmodule TcpClientPool do
  use Agent

  require Logger

  def start_link(_) do
    Logger.info("Starting TcpClientPool ...")

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
