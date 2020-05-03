# TcpServer

To run the server, clone the repository and execute the following command: `iex -S mix`.
After that, you can connect to the TCP server on port 5000 with a TCP client like `telnet` or `nc`:
```
telnet localhost 5000
```
or
```
nc localhost 5000
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tcp_server` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tcp_server, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/tcp_server](https://hexdocs.pm/tcp_server).
