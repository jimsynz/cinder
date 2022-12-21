defmodule Example.App.Route.Slow do
  @moduledoc "An route which will take some time to resolve"
  use Cinder.Route, app: Example.App

  def init(opts) do
    delay = Keyword.get(opts, :delay, 5000)
    request_id = Keyword.get(opts, :request_id)
    {:ok, %{delay: delay, request_id: request_id, params: nil}}
  end

  def enter(state, params) do
    state = Map.put(state, :params, params)

    Task.start(fn ->
      Process.sleep(state.delay)
      transition_complete(state.request_id, :active, state)
    end)

    {:loading, state}
  end

  def exit(state) do
    state = Map.put(state, :params, nil)

    Task.start(fn ->
      Process.sleep(state.delay)
      transition_complete(state.request_id, :inactive, state)
    end)

    {:unloading, state}
  end
end
