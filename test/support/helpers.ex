defmodule TestHelpers do
  @moduledoc false

  alias Cinder.{Engine.State, Route}
  import Cinder.UniqueId

  def build_state(routes, props \\ %{}) do
    %State{
      request_id: unique_id(),
      app: Example.App,
      current_routes: build_entered_routes(routes)
    }
    |> Map.merge(props)
  end

  def build_entered_routes(routes) do
    Enum.map(routes, fn {params, module} ->
      %Route{
        state: :active,
        params: params,
        data: %{params: params},
        module: module
      }
    end)
  end
end
