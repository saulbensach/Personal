defmodule Personal.Worker do
  @moduledoc false

  require Logger

  alias Personal.FileReader

  @http_ver "HTTP/1.1"
  @server "Server: Hyphen Server"

  def work(socket) do
    fun = fn ->
      case :gen_tcp.recv(socket, 0) do
        {:ok, data} ->
          {code, body} = handle_request(data)
          response = "#{@http_ver} #{code}\r\n#{@server}\r\nContent-Type: text/html\r\n\n#{body}\r\n"
          :gen_tcp.send(socket, response)
          :gen_tcp.close(socket)

        {:error, reason} ->
          Logger.error("Failed to read socket socket #{inspect(reason)}")
          :gen_tcp.close(socket)
      end
    end

    pid = spawn(fun)
    :gen_tcp.controlling_process(socket, pid)
  end

  def handle_request("GET " <> rest) do
    path =
      rest
      |> String.split(" ")
      |> List.first()

    body = FileReader.get_file(path)

    if body == nil do
      {"404 Not Found", ""}
    else
      {"200, OK", body}
    end
  end

  def handle_request(_) do
    {"405 Method Not Allowed", ""}
  end
end
