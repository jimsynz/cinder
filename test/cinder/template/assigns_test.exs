defmodule Cinder.Template.AssignsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Cinder.Template.Assigns
  require Cinder.Template.Assigns

  describe "init/0" do
    test "it initialises an empty assigns" do
      assigns = Assigns.init()

      assert Enum.empty?(assigns.data)
      assert Enum.empty?(assigns.undo)
      assert Enum.empty?(assigns.redo)
    end
  end

  describe "push/4" do
    test "it pushes a value into the assigns" do
      assigns =
        Assigns.init()
        |> Assigns.push(:whom, :marty)

      assert assigns[:whom] == :marty
    end

    test "it adds the operation to the undo stack" do
      assigns =
        Assigns.init()
        |> Assigns.push(:whom, :marty, last_name: :mc_fly)

      assert [{:push, "whom", :marty, [last_name: :mc_fly]}] == assigns.undo
    end
  end

  describe "pop/3" do
    test "it removes the value from the assigns" do
      assert {:marty, assigns} =
               Assigns.init()
               |> Assigns.push(:whom, :marty)
               |> Assigns.pop(:whom)

      refute is_map_key(assigns.data, :whom)
    end

    test "it adds the operation to the undo stack" do
      assert {:marty, assigns} =
               Assigns.init()
               |> Assigns.push(:whom, :marty)
               |> Assigns.pop(:whom, meta: true)

      assert [{:pop, "whom", [meta: true]} | _] = assigns.undo
    end

    test "it correctly places the previous value in the data" do
      {:doc, assigns} =
        Assigns.init()
        |> Assigns.push(:whom, :marty)
        |> Assigns.push(:whom, :doc)
        |> Assigns.pop(:whom)

      assert assigns.data["whom"] == :marty
    end
  end

  describe "meta/1" do
    test "it returns the most recent metadata" do
      assigns =
        Assigns.init()
        |> Assigns.push(:whom, :marty, last_name: :mc_fly)

      assert [last_name: :mc_fly] == Assigns.meta(assigns)
    end

    test "when there are no operations, it returns an empty list" do
      assert [] = Assigns.init() |> Assigns.meta()
    end
  end

  describe "fetch/2" do
    test "when there is a value for the key, it returns it" do
      assert {:ok, :marty} = Assigns.init() |> Assigns.push(:whom, :marty) |> Assigns.fetch(:whom)
    end

    test "when there is no value for the key it returns error" do
      assert :error = Assigns.init() |> Assigns.fetch(:whom)
    end
  end

  describe "get_and_update/3" do
    test "new values can be added" do
      assert {nil, assigns} =
               Assigns.init()
               |> Assigns.get_and_update(:whom, fn current ->
                 assert is_nil(current)
                 {current, :marty}
               end)

      assert assigns[:whom] == :marty
      assert [{:push, "whom", :marty, _} | _] = assigns.undo
    end

    test "existing values can be updated" do
      assert {:marty, assigns} =
               Assigns.init()
               |> Assigns.push(:whom, :marty)
               |> Assigns.get_and_update(:whom, fn current ->
                 assert current == :marty
                 {current, :doc_brown}
               end)

      assert assigns[:whom] == :doc_brown
      assert [{:push, "whom", :doc_brown, _} | _] = assigns.undo
    end

    test "existing values can be removed" do
      assert {:marty, assigns} =
               Assigns.init()
               |> Assigns.push(:whom, :marty)
               |> Assigns.get_and_update(:whom, fn current ->
                 assert current == :marty
                 :pop
               end)

      assert assigns[:whom] == nil
      assert [{:pop, "whom", _meta} | _] = assigns.undo
    end
  end

  describe "Enumerable.count/1" do
    test "it returns the number of data elements, not the number of operations" do
      assert 1 ==
               Assigns.init()
               |> Assigns.push(:whom, :marty)
               |> Assigns.push(:whom, :doc_brown)
               |> Enum.count()
    end
  end

  describe "Enumerable.member?/2" do
    test "it checks the existence of a member of the current data elements" do
      assigns =
        Assigns.init()
        |> Assigns.push(:whom, :marty)
        |> Assigns.push(:whom, :doc_brown)

      assert Enum.member?(assigns, {:whom, :doc_brown})
      refute Enum.member?(assigns, {:whom, :marty})
    end
  end

  describe "Enumerable.reduce" do
    test "it reduces over the current data elements only" do
      assigns =
        Assigns.init()
        |> Assigns.push(:number, 1)
        |> Assigns.push(:number, 3)
        |> Assigns.push(:number, 5)

      assert Enum.reduce(assigns, 0, fn {"number", n}, acc -> acc + n end) == 5
    end
  end

  describe "assign/3" do
    test "it pushes the value into the assigns" do
      assigns =
        Assigns.init()
        |> Assigns.assign(:whom, :marty)

      assert assigns[:whom] == :marty
    end

    test "it stores caller metadata in the assigns" do
      meta =
        Assigns.init()
        |> Assigns.assign(:whom, :marty)
        |> Assigns.meta()

      assigned_keys =
        meta
        |> Keyword.keys()
        |> MapSet.new()

      assert MapSet.equal?(
               assigned_keys,
               MapSet.new(~w[context context_modules file function line module]a)
             )

      assert meta[:file] == __ENV__.file
    end
  end

  describe "assign/2" do
    test "it pushes the values into the assigns" do
      assigns =
        Assigns.init()
        |> Assigns.assign(whom: :marty, year: 1985, where: "Hill Valley, Ca.")

      assert assigns[:whom] == :marty
      assert assigns[:year] == 1985
      assert assigns[:where] == "Hill Valley, Ca."
    end

    test "it stores caller metadata in the assigns" do
      meta =
        Assigns.init()
        |> Assigns.assign(whom: :marty, year: 1985, where: "Hill Valley, Ca.")
        |> Assigns.meta()

      assigned_keys =
        meta
        |> Keyword.keys()
        |> MapSet.new()

      assert MapSet.equal?(
               assigned_keys,
               MapSet.new(~w[context context_modules file function line module]a)
             )

      assert meta[:file] == __ENV__.file
    end
  end

  describe "assign_new/3" do
    test "when the key is already present in the assigns, it does nothing" do
      assigns =
        Assigns.init()
        |> Assigns.push(:whom, :marty)
        |> Assigns.assign_new(:whom, :doc_brown)

      assert assigns[:whom] == :marty
    end

    test "when the key is not present in the assigns, it adds it" do
      assigns =
        Assigns.init()
        |> Assigns.assign_new(:whom, :doc_brown)

      assert assigns[:whom] == :doc_brown
    end

    test "it stores caller metadata in the assigns" do
      meta =
        Assigns.init()
        |> Assigns.assign_new(:whom, :doc_brown)
        |> Assigns.meta()

      assigned_keys =
        meta
        |> Keyword.keys()
        |> MapSet.new()

      assert MapSet.equal?(
               assigned_keys,
               MapSet.new(~w[context context_modules file function line module]a)
             )

      assert meta[:file] == __ENV__.file
    end
  end

  describe "undo/1" do
    test "when there is nothing to undo, it returns an error" do
      assert {:error, _} =
               Assigns.init()
               |> Assigns.undo()
    end

    test "it can undo the last push operation" do
      {:ok, assigns} =
        Assigns.init()
        |> Assigns.push(:whom, :marty)
        |> Assigns.push(:whom, :doc_brown)
        |> Assigns.undo()

      assert assigns[:whom] == :marty
      assert [{:push, "whom", :doc_brown, _} | _] = assigns.redo
    end

    test "it can undo the last pop operation" do
      assigns =
        Assigns.init()
        |> Assigns.push(:whom, :marty)

      {_, assigns} = Assigns.pop(assigns, :whom)
      {:ok, assigns} = Assigns.undo(assigns)

      assert assigns[:whom] == :marty
    end

    test "it can undo the last pop operation ... even when it doesn't make sense" do
      assigns = Assigns.init()
      {_, assigns} = Assigns.pop(assigns, :whom)
      {:ok, assigns} = Assigns.undo(assigns)

      refute is_map_key(assigns, :whom)
    end
  end

  describe "redo/1" do
    test "when there is nothing to redo, it returns an error" do
      assert {:error, _} = Assigns.init() |> Assigns.redo()
    end

    test "it can redo the last undone push operation" do
      assigns = Assigns.init() |> Assigns.push(:whom, :marty)
      {:ok, assigns} = Assigns.undo(assigns)
      assert {:ok, assigns} = Assigns.redo(assigns)

      assert assigns[:whom] == :marty
    end

    test "it can redo the last undone pop operation" do
      {_, assigns} = Assigns.init() |> Assigns.push(:whom, :marty) |> Assigns.pop(:whom)

      {:ok, assigns} = Assigns.undo(assigns)
      assert {:ok, assigns} = Assigns.redo(assigns)

      refute is_map_key(assigns.data, :whom)
    end
  end
end
