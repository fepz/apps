defmodule HttpHello.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/hello/:name" do
    send_response(conn, "Hello, #{name}")
  end

  get "/hola/:name" do
    send_response(conn, "Hola, #{name}")
  end

  defp send_response(conn, response) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, response)
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
