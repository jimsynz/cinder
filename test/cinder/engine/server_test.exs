defmodule Cinder.Engine.ServerTest do
  use ExUnit.Case, async: true
  alias Cinder.{Engine.Server, Engine.State, UniqueId}
  alias Phoenix.PubSub
  alias Spark.Dsl.Extension

  setup do
    session_id = UniqueId.unique_id()
    {:ok, pid} = Server.start_link(Example.App, session_id)
    {:ok, session_id: session_id, pid: pid}
  end

  describe "init/1" do
    test "it stores the session id in the server state", %{session_id: session_id, pid: pid} do
      assert %State{session_id: ^session_id} = GenServer.call(pid, :get_state)
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
      |> Extension.get_persisted(:cinder_engine_pubsub)
      |> PubSub.broadcast(
        "cinder_engine_server:#{state.session_id}",
        {:transition_complete, Example.App.Route.Stuck, :active, %{}}
      )

      state = GenServer.call(pid, :get_state)
      assert state.status == :idle

      assert [
               %{state: :active, module: Example.App.Route.App},
               %{state: :active, module: Example.App.Route.Stuck}
             ] = state.current_routes
    end
  end
end
