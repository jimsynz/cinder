defmodule Cinder.Plug.RequestHandler do
  @moduledoc """
  Take an inbound HTTP request and send it an engine for processing.
  """
  alias Spark.Dsl.Extension

  @behaviour Plug
  @type opts :: %{required(:app) => Cinder.app(), optional(atom) => any}

  import Plug.Conn

  @doc false
  @impl true
  @spec init(keyword) :: opts
  def init(opts), do: Map.new(opts)

  @doc false
  @impl true
  @spec call(Plug.Conn.t(), opts) :: Plug.Conn.t()
  def call(conn, opts) do
    session_key = Extension.get_persisted(opts.app, :cinder_session_key)

    session_id =
      case get_session(conn, session_key) do
        nil -> raise "Missing Cinder session ID!"
        session_id -> session_id
      end

    engine = Extension.get_persisted(opts.app, :cinder_engine)

    engine.start!(session_id)
    engine.transition_to(session_id, conn.path_info, conn.params)

    send_resp(conn, 200, engine.render_once(session_id))
  end
end
