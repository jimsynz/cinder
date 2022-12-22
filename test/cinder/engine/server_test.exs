defmodule Cinder.Engine.ServerTest do
  use ExUnit.Case, async: true
  alias Cinder.{Engine.Server, Engine.State, Route, UniqueId}

  setup do
    request_id = UniqueId.unique_id()
    {:ok, pid} = Server.start_link(Example.App, request_id)
    {:ok, request_id: request_id, pid: pid}
  end

  describe "init/1" do
    test "it stores the session id in the server state", %{request_id: request_id, pid: pid} do
      assert %State{request_id: ^request_id} = GenServer.call(pid, :get_state)
    end

    test "it stores the app in the server state", %{pid: pid} do
      assert %State{app: Example.App} = GenServer.call(pid, :get_state)
    end

    test "it starts in idle state", %{pid: pid} do
      assert %State{status: :idle} = GenServer.call(pid, :get_state)
    end

    test "it starts with empty routes", %{pid: pid} do
      assert %State{current_routes: []} = GenServer.call(pid, :get_state)
    end

    test "it starts with an empty op stack", %{pid: pid} do
      assert %State{op_stack: []} = GenServer.call(pid, :get_state)
    end
  end

  describe "handle_cast/2" do
    test "it can transition to a new route", %{pid: pid} do
      GenServer.cast(pid, {:transition_to, "/posts/123/comments"})

      state = GenServer.call(pid, :get_state)
      assert state.status == :idle

      assert [
               %{state: :active, module: Example.App.Route.App},
               %{state: :active, module: Example.App.Route.Posts},
               %{state: :active, module: Example.App.Route.Post, params: %{"id" => "123"}},
               %{state: :active, module: Example.App.Route.Comments}
             ] = state.current_routes
    end

    test "it can asynchronously transition to a new route", %{pid: pid} do
      GenServer.cast(pid, {:transition_to, "/stuck"})

      state = GenServer.call(pid, :get_state)
      assert state.status == :transition_paused

      assert [
               %{state: :active, module: Example.App.Route.App},
               %{state: :loading, module: Example.App.Route.Stuck}
             ] = state.current_routes

      Example.App
      |> Route.transition_complete(Example.App.Route.Stuck, state.request_id, :active, %{})

      state = GenServer.call(pid, :get_state)
      assert state.status == :idle

      assert [
               %{state: :active, module: Example.App.Route.App},
               %{state: :active, module: Example.App.Route.Stuck}
             ] = state.current_routes
    end
  end
end
