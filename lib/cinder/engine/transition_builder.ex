defmodule Cinder.Engine.TransitionBuilder do
  @moduledoc """
  Contains the logic for building transitions from one route to another.
  """

  alias Cinder.{Engine.State, Route}

  @doc """
  Build a transition to a new route.

  This builds a stack of operations which when executed will transition the
  engine to a new route.
  """
  @spec build_transition_to(State.t(), [Route.t() | {Route.params(), Route.route_module()}]) ::
          State.t()
  def build_transition_to(state, routes) do
    routes =
      routes
      |> Stream.map(&%{params: elem(&1, 0), module: elem(&1, 1)})
      |> Stream.reject(&is_nil(&1.module))

    op_stack =
      state.current_routes
      |> Stream.map(&Map.take(&1, ~w[params module state]a))
      |> zip_to_longest(routes)
      |> build_op_stack([])

    %{state | op_stack: op_stack, status: :transitioning}
  end

  # when the op stack is empty (there are no parental changes) so we can ignore
  # matching routes.
  defp build_op_stack(stream, []) do
    case stream_hd(stream) do
      {nil, _stream} ->
        []

      {{current, nil}, stream} ->
        build_op_stack(stream, [{:exit, current.module}])

      {{nil, next}, stream} ->
        build_op_stack(stream, [{:enter, next.module, next.params}])

      {{current, next}, stream}
      when current.module == next.module and current.params == next.params and
             current.state == :active ->
        build_op_stack(stream, [])

      {{current, next}, stream} ->
        build_op_stack(stream, [{:exit, current.module}, {:enter, next.module, next.params}])
    end
  end

  # since we know there are changes in the op stack already our parent routes
  # must be changing, so we're going to assume that everything after needs to be
  # re-entered.
  defp build_op_stack(stream, op_stack) do
    case stream_hd(stream) do
      {nil, _stream} ->
        op_stack

      {{current, nil}, stream} ->
        build_op_stack(stream, [{:exit, current.module} | op_stack])

      {{nil, next}, stream} ->
        build_op_stack(stream, op_stack ++ [{:enter, next.module, next.params}])

      {{current, next}, stream} ->
        build_op_stack(
          stream,
          [{:exit, current.module} | op_stack] ++ [{:enter, next.module, next.params}]
        )
    end
  end

  # takes two, possibly different length enumerables and zips them, but doesn't
  # stop until both inputs are empty.
  defp zip_to_longest(lhs, rhs) do
    Stream.resource(
      fn -> {lhs, rhs} end,
      fn {lhs, rhs} ->
        case {stream_hd(lhs), stream_hd(rhs)} do
          {{nil, _lhs}, {nil, _rhs}} -> {:halt, nil}
          {{a, lhs}, {nil, rhs}} -> {[{a, nil}], {lhs, rhs}}
          {{nil, lhs}, {b, rhs}} -> {[{nil, b}], {lhs, rhs}}
          {{a, lhs}, {b, rhs}} -> {[{a, b}], {lhs, rhs}}
        end
      end,
      fn _ -> nil end
    )
  end

  # Return the first element if the stream (or `nil`), and the rest of the stream.
  defp stream_hd(stream), do: {Enum.at(stream, 0), Stream.drop(stream, 1)}
end
