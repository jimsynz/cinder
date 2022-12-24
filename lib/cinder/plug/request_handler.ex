defmodule Cinder.Plug.RequestHandler do
  @moduledoc """
  Take an inbound HTTP request and send it an engine for processing.
  """
  alias Spark.Dsl.Extension

  @behaviour Plug
  @type opts :: %{required(:app) => Cinder.app(), optional(atom) => any}

  @doc false
  @impl true
  @spec init(keyword) :: opts
  def init(opts), do: Map.new(opts)

  @doc false
  @impl true
  @spec call(Plug.Conn.t(), opts) :: Plug.Conn.t()
  def call(conn, opts) do
    request_key = Extension.get_persisted(opts.app, :cinder_request_key)

    request_id =
      case Map.fetch(conn.private, request_key) do
        {:ok, request_id} -> request_id
        :error -> raise "Missing Cinder request ID!"
      end

    engine = Extension.get_persisted(opts.app, :cinder_engine)
    engine.start!(request_id)
    engine.transition_to(request_id, conn.path_info, conn.params)
    engine.render_once(request_id, conn)
  end
end
