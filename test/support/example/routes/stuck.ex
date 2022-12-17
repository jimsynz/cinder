defmodule Example.App.Route.Stuck do
  @moduledoc "An route which will never resolve"
  use Cinder.Route, app: Example.App

  def init(_opts), do: {:ok, %{}}

  def enter(state, params) do
    {:loading, Map.put(state, :params, params)}
  end

  def exit(state) do
    {:unloading, state}
  end
end
