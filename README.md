# Convo

To run the server, clone the repository and execute the following command: `iex -S mix` (ensure that port 5000 is available).
After that, you can connect to the TCP server on port 5000 with a TCP client like `telnet` or `netcat`:
```
telnet localhost 5000
```
or
```
nc localhost 5000
```
## Features

- the server handles simultaneous connections
- users can executes commands, and display documentation
- users can change their username
- users can create rooms
