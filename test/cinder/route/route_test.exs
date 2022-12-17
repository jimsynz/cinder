defmodule Cinder.RouteTest do
  use ExUnit.Case, async: true
  alias Cinder.Route
  alias Example.App.Route.Posts

  describe "init/2" do
    test "it initialises a route in empty state" do
      assert {:ok, route} = Route.init(Posts, [])

      assert route.state == :initial
      assert route.data == []
      assert route.module == Posts
    end
  end

  describe "enter/2" do
    test "it attempts to enter a route" do
      {:ok, route} = Route.init(Posts, [])

      assert {:active, route} = Route.enter(route, %{})
      assert route.state == :active
    end
  end

  describe "exit/1" do
    test "it attempts to exit a route" do
      {:ok, route} = Route.init(Posts, [])
      {:active, route} = Route.enter(route, %{})
      assert {:inactive, route} = Route.exit(route)

      assert route.state == :inactive
    end
  end

  describe "resource/1" do
    test "it asks the route for the resource" do
      {:ok, route} = Route.init(Posts, [])
      {:active, route} = Route.enter(route, %{})

      assert {:ok, nil} = Route.resource(route)
    end
  end
end
