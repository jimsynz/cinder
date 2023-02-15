defmodule Cinder.Engine.Server do
  @moduledoc """
  The main request server.
  """
  use GenServer, restart: :transient

  alias Cinder.{
    Engine,
    Engine.Macros,
    Engine.Server,
    Engine.State,
    Engine.TransitionBuilder,
    Engine.TransitionExecutor,
    Route,
    Route.Matcher,
    Template.Assigns,
    Template.Render,
    Template.Rendered.AssignCompose,
    Template.Rendered.SlotCompose,
    Template.Rendered.Static
  }

  alias Plug.Conn
  alias Spark.Dsl.Extension

  import Macros
  require Logger
  require Assigns

  @doc false
  @spec start_link(module, Engine.request_id()) :: GenServer.on_start()
  def start_link(app, request_id),
    do: GenServer.start_link(Server, [app, request_id], name: via(app, request_id))

  @impl true
  @spec init(list) :: {:ok, State.t(), pos_integer()}
  def init([app, request_id]) do
    {:ok, %State{request_id: request_id, app: app}, timeout(app)}
  end

  @impl true
  # sobelow_skip ["XSS.SendResp"]
  def handle_call({:render_once, conn}, _from, state) do
    html =
      state
      |> render(true)
      |> Render.execute(Assigns.init(), Assigns.init(), Assigns.init())

    conn =
      conn
      |> Conn.put_resp_content_type("text/html")
      |> Conn.send_resp(state.http_status, html)

    {:reply, conn, state, timeout(state.app)}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call(:request_id, _from, state), do: {:reply, state.request_id, state}

  @impl true
  def handle_cast({:transition_to, path_and_query}, state) when is_binary(path_and_query),
    do: handle_cast({:transition_to, path_and_query, %{}}, state)

  def handle_cast({:transition_to, path_and_query, params}, state)
      when is_binary(path_and_query) do
    case String.split(path_and_query, "?", parts: 2) do
      [path, query] ->
        params =
          query
          |> URI.decode_query()
          |> Map.merge(params)

        handle_cast({:transition_to, Path.split(path), params}, state)

      ["", query] ->
        params =
          query
          |> URI.decode_query()
          |> Map.merge(params)

        handle_cast({:transition_to, ["/"], params}, state)

      [path] ->
        handle_cast({:transition_to, Path.split(path), params}, state)
    end
  end

  def handle_cast({:transition_to, path_info, params}, state) when is_list(path_info) do
    state = %{state | path_info: path_info, params: params}

    Logger.debug(
      "[#{state.request_id}] Transitioning to #{inspect(path_info)} :: #{inspect(params)}"
    )

    path_info
    |> Matcher.match(state.app.__cinder_routing_table__())
    |> case do
      {:ok, routes} ->
        state =
          state
          |> TransitionBuilder.build_transition_to(routes)
          |> execute_transition()

        {:noreply, state}

      :error ->
        state =
          %{state | http_status: 404}
          |> TransitionBuilder.build_transition_to_error(%{
            "reason" => "route not found",
            "status" => "404"
          })
          |> execute_transition()

        {:noreply, state}
    end
  end

  def handle_cast({:transition_complete, module, new_state, data}, state)
      when state.status == :transition_paused do
    state =
      state
      |> update_route_by_module(module, &%{&1 | state: new_state, data: data})
      |> Map.put(:status, :transitioning)
      |> execute_transition()

    {:noreply, state}
  end

  def handle_cast({:transition_complete, module, new_state, _data}, state) do
    Logger.debug(
      "Ignoring transition #{inspect(module)}/#{inspect(new_state)} because we're no longer transitioning"
    )

    {:noreply, state}
  end

  def handle_cast({:socket, pid}, state) do
    Logger.debug("[#{state.request_id}] Adding pid #{inspect(pid)} to sockets")
    Process.monitor(pid)

    {:noreply, %{state | sockets: [pid | state.sockets]}}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.debug("[#{state.request_id}] Reconnect timeout.")
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    Logger.debug("[#{state.request_id}] Removing pid #{inspect(pid)} from sockets")

    sockets = List.delete(state.sockets, pid)

    if Enum.empty?(sockets) do
      {:noreply, %{state | sockets: sockets}, timeout(state.app)}
    else
      {:noreply, %{state | sockets: sockets}}
    end
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

  defp timeout(app) do
    app
    |> Extension.get_opt([:cinder, :engine], :reconnect_timeout, 10)
    |> then(&(&1 * 1_000))
  end

  # defp render(state, include_layout)
  defp render(state, false) do
    state.current_routes
    |> Enum.reverse()
    |> Enum.reduce(Static.init([]), fn route, inner ->
      assigns =
        route
        |> Route.assigns()
        |> Map.put(:request, State.to_request(state))
        |> Assigns.init()

      state_template =
        route.state
        |> route.module.template()
        |> SlotCompose.init(inner)

      :base
      |> route.module.template()
      |> SlotCompose.init(state_template)
      |> AssignCompose.init(assigns)
    end)
  end

  defp render(state, true) do
    inner = render(state, false)
    layout = Extension.get_persisted(state.app, :cinder_layout)
    template = layout.template()
    assigns = Assigns.init(request: State.to_request(state))

    template
    |> AssignCompose.init(assigns)
    |> SlotCompose.init(inner)
  end

  defp execute_transition(state) do
    state
    |> TransitionExecutor.execute_transition()
    |> tap(fn
      %{status: :idle, current_routes: routes} ->
        Logger.debug("[#{state.request_id}] Transition complete: #{inspect(routes)}")

      %{status: :transition_paused, current_routes: routes} ->
        Logger.debug("[#{state.request_id}] Transition paused: #{inspect(routes)}")
    end)
    |> maybe_broadcast_changes()
  end

  defp maybe_broadcast_changes(state) when state.sockets == [], do: state

  defp maybe_broadcast_changes(state) do
    html =
      state
      |> render(false)
      |> Render.execute(Assigns.init(), Assigns.init(), Assigns.init())

    for pid <- state.sockets do
      send(pid, {:rerender, html})
    end

    state
  end
end
