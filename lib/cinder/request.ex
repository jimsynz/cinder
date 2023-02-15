defmodule Cinder.Request do
  @moduledoc """
  Contains information about the current request, which can be used in
  templates.
  """

  defstruct app: nil,
            current_route: nil,
            current_routes: [],
            pid: nil,
            request_id: nil

  alias Cinder.{
    Engine,
    Request,
    Route
  }

  @type t :: %Request{
          app: Cinder.app(),
          current_route: Route.t(),
          current_routes: [Route.t()],
          pid: pid,
          request_id: Engine.request_id()
        }

  @behaviour Access

  @doc false
  @impl true
  def fetch(request, key), do: Map.fetch(request, key)

  @doc false
  @impl true
  def get_and_update(data, key, function), do: Map.get_and_update(data, key, function)

  @doc false
  @impl true
  def pop(data, key), do: Map.pop(data, key)
end
