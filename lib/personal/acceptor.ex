defmodule Personal.Acceptor do
  @moduledoc false
  use Supervisor

  require Logger

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    children = [
      Supervisor.child_spec({Task, fn -> accept(port) end}, restart: :permanent)
    ]


    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end

  defp accept(port) do
    {:ok, listen_socket} = :gen_tcp.listen(
      port,
      [
        :binary,
        packet: :line,
        active: false,
        reuseaddr: true,
        nodelay: true,
        backlog: 1024
      ]
    )

    Logger.info("Listening port: #{port}")

    loop(listen_socket)
  end

  defp loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        Personal.Worker.work(socket)

      {:error, reason} ->
        Logger.error("Failed to accept connection #{inspect(reason)}")
    end

    loop(listen_socket)
  end
end
