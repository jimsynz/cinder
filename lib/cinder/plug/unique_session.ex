defmodule Cinder.Plug.UniqueSession do
  @moduledoc """
  Ensure that every request has a unique session identifier.

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
    session_key = Extension.get_persisted(opts.app, :cinder_session_key)

    session_id =
      conn
      |> get_session(session_key)
      |> case do
        nil -> unique_id(opts.length)
        id when is_binary(id) -> id
      end

    conn
    |> put_session(session_key, session_id)
  end
end
