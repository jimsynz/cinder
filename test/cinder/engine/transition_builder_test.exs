defmodule Cinder.Engine.TransitionBuilderTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Cinder.Engine.TransitionBuilder
  import TestHelpers
  doctest Cinder.Engine.TransitionBuilder

  describe "build_transition_to/2" do
    test "build a transition from / to /posts" do
      state =
        [{%{}, Example.App.Route.App}]
        |> build_state()
        |> build_transition_to([{%{}, Example.App.Route.App}, {%{}, Example.App.Route.Posts}])

      assert state.status == :transitioning
      assert state.op_stack == [{:enter, Example.App.Route.Posts, %{}}]
    end

    test "build a transition from / to /posts/123/comments" do
      state =
        [{%{}, Example.App.Route.App}]
        |> build_state()
        |> build_transition_to([
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "123"}, Example.App.Route.Post},
          {%{}, Example.App.Route.Comments}
        ])

      assert state.status == :transitioning

      assert state.op_stack == [
               {:enter, Example.App.Route.Posts, %{}},
               {:enter, Example.App.Route.Post, %{"id" => "123"}},
               {:enter, Example.App.Route.Comments, %{}}
             ]
    end

    test "build a transition from /posts/123/comments to /posts" do
      state =
        [
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "123"}, Example.App.Route.Post},
          {%{}, Example.App.Route.Comments}
        ]
        |> build_state()
        |> build_transition_to([{%{}, Example.App.Route.App}])

      assert state.status == :transitioning

      assert [
               {:exit, Example.App.Route.Comments},
               {:exit, Example.App.Route.Post},
               {:exit, Example.App.Route.Posts}
             ] = state.op_stack
    end

    test "build a transition from /posts/123/comments to /posts/456/comments" do
      state =
        [
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "123"}, Example.App.Route.Post},
          {%{}, Example.App.Route.Comments}
        ]
        |> build_state()
        |> build_transition_to([
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "456"}, Example.App.Route.Post},
          {%{}, Example.App.Route.Comments}
        ])

      assert state.status == :transitioning

      assert [
               {:exit, Example.App.Route.Comments},
               {:exit, Example.App.Route.Post},
               {:enter, Example.App.Route.Post, %{"id" => "456"}},
               {:enter, Example.App.Route.Comments, %{}}
             ] = state.op_stack
    end

    test "build a transition from /posts/123/comments/abc to /posts/456/comments/def" do
      state =
        [
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "123"}, Example.App.Route.Post},
          {%{}, Example.App.Route.Comments},
          {%{"id" => "abc"}, Example.App.Route.Comment}
        ]
        |> build_state()
        |> build_transition_to([
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "456"}, Example.App.Route.Post},
          {%{}, Example.App.Route.Comments},
          {%{"id" => "def"}, Example.App.Route.Comment}
        ])

      assert state.status == :transitioning

      assert [
               {:exit, Example.App.Route.Comment},
               {:exit, Example.App.Route.Comments},
               {:exit, Example.App.Route.Post},
               {:enter, Example.App.Route.Post, %{"id" => "456"}},
               {:enter, Example.App.Route.Comments, %{}},
               {:enter, Example.App.Route.Comment, %{"id" => "def"}}
             ] = state.op_stack
    end

    test "build transition from / to /fruits/banana" do
      state =
        [{%{}, Example.App.Route.App}]
        |> build_state()
        |> build_transition_to([
          {%{}, Example.App.Route.App},
          {%{}, nil},
          {%{"id" => "banana"}, Example.App.Route.Fruit}
        ])

      assert state.status == :transitioning

      assert [
               {:enter, Example.App.Route.Fruit, %{"id" => "banana"}}
             ] = state.op_stack
    end

    test "build transition from /fruits/banana to /" do
      state =
        [{%{}, Example.App.Route.App}, {%{"id" => "banana"}, Example.App.Route.Fruit}]
        |> build_state()
        |> build_transition_to([{%{}, Example.App.Route.App}])

      assert state.status == :transitioning

      assert [
               {:exit, Example.App.Route.Fruit}
             ] = state.op_stack
    end
  end

  describe "build_transition_to_error/2" do
    test "build transition from /posts/123/comments to error" do
      state =
        [
          {%{}, Example.App.Route.App},
          {%{}, Example.App.Route.Posts},
          {%{"id" => "123"}, Example.App.Route.Post},
          {%{}, Example.App.Route.Comments}
        ]
        |> build_state()
        |> build_transition_to_error(%{"reason" => "Please refill Mr Fusion."})

      assert state.status == :transitioning

      assert [
               {:exit, Example.App.Route.Comments},
               {:exit, Example.App.Route.Post},
               {:exit, Example.App.Route.Posts},
               {:error, %{"reason" => "Please refill Mr Fusion."}, Example.App.Route.App}
             ] = state.op_stack
    end
  end
end
