defmodule Example.App.Route.Slow do
  @moduledoc "An route which will take some time to resolve"
  use Cinder.Route, app: Example.App

  def init(opts) do
    delay = Keyword.get(opts, :delay, 5000)
    session_id = Keyword.get(opts, :session_id)
    {:ok, %{delay: delay, session_id: session_id, params: nil}}
  end

  def enter(state, params) do
    state = Map.put(state, :params, params)

    Task.start(fn ->
      Process.sleep(state.delay)
      transition_complete(state.session_id, :active, state)
    end)

    {:loading, state}
  end

  def exit(state) do
    state = Map.put(state, :params, nil)

    Task.start(fn ->
      Process.sleep(state.delay)
      transition_complete(state.session_id, :inactive, state)
    end)

    {:unloading, state}
  end
end
