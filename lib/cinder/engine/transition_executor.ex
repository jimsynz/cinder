defmodule Cinder.Engine.TransitionExecutor do
  @moduledoc """
  Attempt to execute a route transition.

  When given a state containing a non-empty op stack and whose status is
  `:transitioning` we can attempt to execute the stack.

  Because routes can be asynchronous it's possible that we can only execute
  *some* of the transition and rely on the engine to re-enter the transition
  at a later time.

  FIXME: Currently raises on error instead of forcing into app/error.
  """
  alias Cinder.{Engine.State, Route}
  require Logger

  @doc "Attempt to execute a transition"
  @spec execute_transition(State.t()) :: State.t()
  def execute_transition(state) when state.status == :transitioning,
    do: do_execute_transition(state.op_stack, Enum.reverse(state.current_routes), state)

  defp do_execute_transition([], current_routes, state),
    do: %{state | op_stack: [], current_routes: Enum.reverse(current_routes), status: :idle}

  defp do_execute_transition([{:exit, _} | _], [], _state) do
    raise "Error in transition - ran out of routes while executing!"
  end

  # This route has finished unloading and can be popped.
  defp do_execute_transition([{:exit, module} | op_stack], [route | current_routes], state)
       when module == route.module and route.state in ~w[inactive error]a,
       do: do_execute_transition(op_stack, current_routes, state)

  defp do_execute_transition([{:exit, module} | op_stack], [route | current_routes], state)
       when module == route.module do
    case Route.exit(route) do
      {:unloading, route} ->
        # the route needs time to unload, so we exit early.
        %{
          state
          | op_stack: [{:exit, module} | op_stack],
            current_routes: Enum.reverse([route | current_routes]),
            status: :transition_paused
        }

      {:inactive, _route} ->
        do_execute_transition(op_stack, current_routes, state)

      {:error, route} ->
        do_execute_transition(op_stack, [route | current_routes], state)
    end
  end

  defp do_execute_transition([{:exit, module} | _], [route | _], _state) do
    raise "Error in transition - expected `#{inspect(module)}`, got `#{inspect(route.module)}`"
  end

  defp do_execute_transition(
         [{:enter, module, params} | op_stack],
         [route | current_routes],
         state
       )
       when route.module == module do
    case Route.enter(route, params) do
      {:loading, route} ->
        # the route needs time to load, so we exit early.
        %{
          state
          | op_stack: [{:enter, module, params} | op_stack],
            current_routes: Enum.reverse([route | current_routes]),
            status: :transition_paused
        }

      {:active, route} ->
        do_execute_transition(op_stack, [route | current_routes], state)

      {:error, route} ->
        do_execute_transition(op_stack, [route | current_routes], state)
    end
  end

  defp do_execute_transition([{:enter, module, params} | op_stack], current_routes, state) do
    {:ok, route} = Route.init(module, request_id: state.request_id)
    do_execute_transition([{:enter, module, params} | op_stack], [route | current_routes], state)
  end

  defp do_execute_transition(
         [{:error, params, module} | op_stack],
         [route | current_routes],
         state
       )
       when module == route.module do
    {:error, route} = Route.error(route, params)
    do_execute_transition(op_stack, [route | current_routes], state)
  end

  defp do_execute_transition([{:error, params, module} | op_stack], current_routes, state) do
    {:ok, route} = Route.init(module, request_id: state.request_id)
    do_execute_transition([{:error, module, params} | op_stack], [route | current_routes], state)
  end
end
