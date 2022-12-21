defmodule Cinder.Plug.RequestId do
  @moduledoc """
  Ensure that every request has a unique identifier.

  This is used map requests to instances of `Cinder.Engine.Server`.
  """

  @behaviour Plug
  @type opts :: %{
          required(:app) => Cinder.app(),
          required(:length) => pos_integer,
          optional(atom) => any
        }

  alias Spark.Dsl.Extension

  import Cinder.UniqueId
  import Plug.Conn

  @doc false
  @impl true
  @spec init(keyword) :: opts
  def init(opts) do
    opts
    |> Map.new()
    |> Map.put_new(:length, 32)
  end

  @doc false
  @impl true
  @spec call(Plug.Conn.t(), opts) :: Plug.Conn.t()
  def call(conn, opts) do
    request_key = Extension.get_persisted(opts.app, :cinder_request_key)

    request_id =
      with :error <- request_id_from_private(conn, request_key),
           :error <- request_id_from_header(conn) do
        unique_id(opts.length)
      else
        {:ok, request_id} -> request_id
      end

    conn
    |> put_private(request_key, request_id)
  end

  defp request_id_from_private(conn, request_key), do: Map.fetch(conn.private, request_key)

  defp request_id_from_header(conn) do
    conn
    |> get_req_header("Cinder-Request-Id")
    |> case do
      [request_id | _] -> {:ok, request_id}
      [] -> :error
    end
  end
end
