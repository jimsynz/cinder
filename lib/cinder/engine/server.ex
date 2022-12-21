defmodule Cinder.Engine.Server do
  @moduledoc """
  The main request server.
  """
  use GenServer

  alias Cinder.{
    Engine.Macros,
    Engine.Server,
    Engine.State,
    Engine.TransitionBuilder,
    Engine.TransitionExecutor,
    Route.Matcher
  }

  alias Phoenix.PubSub
  alias Spark.Dsl.Extension

  import Macros
  require Logger

  @doc false
  @spec start_link(module, String.t()) :: GenServer.on_start()
  def start_link(app, session_id),
    do: GenServer.start_link(Server, [app, session_id], name: via(app, session_id))

  @impl true
  @spec init(list) :: {:ok, State.t(), pos_integer()}
  def init([app, session_id]) do
    timeout =
      app
      |> Extension.get_opt([:cinder, :engine], :server_idle_timeout, 300)
      |> then(&(&1 * 1_000))

    pubsub = Extension.get_persisted(app, :cinder_engine_pubsub)

    :ok = PubSub.subscribe(pubsub, "cinder_engine_server:#{session_id}")

    {:ok, %State{session_id: session_id, app: app}, timeout}
  end

  @impl true
  def handle_call(:render_once, _from, state) do
    {:reply, inspect(state), state}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call(:session_id, _from, state), do: {:reply, state.session_id, state}

  @impl true
  def handle_cast({:transition_to, path_and_query}, state) when is_binary(path_and_query) do
    case String.split(path_and_query, "?", parts: 2) do
      [path, query] ->
        handle_cast({:transition_to, Path.split(path), URI.decode_query(query)}, state)

      ["", query] ->
        handle_cast({:transition_to, ["/"], URI.decode_query(query)}, state)

      [path] ->
        handle_cast({:transition_to, Path.split(path), %{}}, state)
    end
  end

  def handle_cast({:transition_to, path_info, params}, state) do
    state = %{state | path_info: path_info, params: params}

    state =
      path_info
      |> Matcher.match(state.app.__routing_table__())
      |> case do
        {:ok, routes} ->
          state
          |> TransitionBuilder.build_transition_to(routes)
          |> TransitionExecutor.execute_transition()

        :error ->
          Logger.debug("ignoring a 404")
          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.debug("Session #{state.session_id} timeout")
    {:stop, :normal, state}
  end

  def handle_info({:transition_complete, module, new_state, data}, state)
      when state.status == :transition_paused do
    state =
      state
      |> update_route_by_module(module, &%{&1 | state: new_state, data: data})
      |> Map.put(:status, :transitioning)
      |> TransitionExecutor.execute_transition()

    {:noreply, state}
  end

  def handle_info({:transition_complete, module, new_state, _data}, state) do
    Logger.debug(
      "Ignoring transition #{inspect(module)}/#{inspect(new_state)} because we're no longer transitioning"
    )

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Ignoring message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp update_route_by_module(state, module, callback) when is_function(callback, 1) do
    current_routes =
      state.current_routes
      |> Enum.map(fn route ->
        if route.module == module do
          callback.(route)
        else
          route
        end
      end)

    %{state | current_routes: current_routes}
  end
end
