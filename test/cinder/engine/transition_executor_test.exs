defmodule Cinder.Engine.TransitionExecutorTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Cinder.Engine.TransitionBuilder
  import Cinder.Engine.TransitionExecutor
  import TestHelpers
  doctest Cinder.Engine.TransitionExecutor

  describe "execute_transition/1" do
    test "when there are no pending operations, it becomes idle" do
      state =
        [{%{}, Example.App.Route.App}]
        |> build_state(%{status: :transitioning})
        |> execute_transition()

      assert state.status == :idle
    end

    test "when entering routes which activate immediately it continues until it is finished" do
      state =
        [{%{}, Example.App.Route.App}]
        |> build_state()
        |> build_transition_to([
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "123"}, Example.App.Route.Post}
        ])
        |> execute_transition()

      assert state.status == :idle

      assert [
               %{state: :active, module: Example.App.Route.App},
               %{state: :active, module: Example.App.Route.Posts},
               %{state: :active, module: Example.App.Route.Post}
             ] = state.current_routes
    end

    test "when exiting routes which deactivate immediately it continues until it is finished" do
      state =
        [
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "123"}, Example.App.Route.Post}
        ]
        |> build_state()
        |> build_transition_to([{%{}, Example.App.Route.App}])
        |> execute_transition()

      assert state.status == :idle

      assert [%{state: :active, module: Example.App.Route.App}] = state.current_routes
    end

    test "when entering a route which enters loading state, it pauses the transition" do
      state =
        [{%{}, Example.App.Route.App}]
        |> build_state()
        |> build_transition_to([{%{}, Example.App.Route.App}, {%{}, Example.App.Route.Stuck}])
        |> execute_transition()

      assert state.status == :transition_paused

      assert [
               %{state: :active, module: Example.App.Route.App},
               %{state: :loading, module: Example.App.Route.Stuck}
             ] = state.current_routes
    end

    test "when exiting a route which enters unloading state, it pauses the transition" do
      state =
        [{%{}, Example.App.Route.App}, {%{}, Example.App.Route.Stuck}]
        |> build_state()
        |> build_transition_to([{%{}, Example.App.Route.App}])
        |> execute_transition()

      assert state.status == :transition_paused

      assert [
               %{state: :active, module: Example.App.Route.App},
               %{state: :unloading, module: Example.App.Route.Stuck}
             ] = state.current_routes
    end
  end
end
