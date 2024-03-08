defmodule Cinder.Template.SlotStack do
  @moduledoc """
  Provides simple stack semantics for slots.

  We can treat slots much like local variables.  Each time we descent into a new
  "yield" or component we need to push slots onto the stack and then remove them
  again afterwards.
  """

  defstruct stack: [%{}]

  alias Cinder.Template.{Render, SlotStack}

  @type scope :: %{required(atom) => Render.t()}

  @type t :: %SlotStack{stack: [scope]}

  @doc """
  Initialise a new slot stack
  """
  @spec init(scope) :: t
  def init(scope \\ %{}), do: %SlotStack{stack: [scope]}

  @doc """
  Push a new scope of scope onto the stack.
  """
  @spec push(t, scope) :: t
  def push(slot_stack, scope \\ %{}) when is_struct(slot_stack, SlotStack),
    do: %SlotStack{stack: [scope | slot_stack.stack]}

  @doc """
  Remove the top scope from the stack and return the remainder of the stack.
  """
  @spec pop(t) :: t
  def pop(%SlotStack{stack: [_ | [_ | _] = stack]}), do: %SlotStack{stack: stack}

  @doc """
  Add a slot into the current scope.
  """
  @spec set(t, atom, Render.t()) :: t
  def set(%SlotStack{stack: [head | tail]}, name, slot) when is_atom(name),
    do: %SlotStack{stack: [Map.put(head, name, slot) | tail]}

  @doc """
  Fetch a slot from the current scope.
  """
  @spec fetch_current(t, atom) :: {:ok, Render.t()} | :error
  def fetch_current(%SlotStack{stack: [head | _]}, name) when is_atom(name),
    do: Map.fetch(head, name)

  @doc """
  Fetch the first occurrence of a slot from the stack.
  """
  @spec fetch(t, atom) :: {:ok, Render.t()} | :error
  def fetch(%SlotStack{stack: stack}, name) when is_atom(name) do
    Enum.reduce_while(stack, :error, fn scope, :error ->
      case Map.fetch(scope, name) do
        {:ok, slot} -> {:halt, {:ok, slot}}
        :error -> {:cont, :error}
      end
    end)
  end

  @doc """
  Get the first occurrence of a slot from the stack.
  """
  @spec get(t, atom) :: Render.t() | nil
  def get(slot_stack, name, default \\ nil)
      when is_struct(slot_stack, SlotStack) and is_atom(name) do
    case fetch(slot_stack, name) do
      {:ok, slot} -> slot
      :error -> default
    end
  end

  @doc """
  Does the current scope contain the named slot?
  """
  @spec has_current_slot?(t, atom) :: boolean
  def has_current_slot?(%SlotStack{stack: [head | _]}, name) when is_atom(name),
    do: Map.has_key?(head, name)

  @doc """
  Does any scope contain the named slot?
  """
  @spec has_slot?(t, atom | binary) :: boolean
  def has_slot?(%SlotStack{stack: stack}, name) when is_atom(name) do
    Enum.reduce_while(stack, false, fn scope, false ->
      if Map.has_key?(scope, name) do
        {:halt, true}
      else
        {:cont, false}
      end
    end)
  end

  @doc """
  Return a list of the slots in the current stack.
  """
  @spec current_keys(t) :: MapSet.t(atom)
  def current_keys(%SlotStack{stack: [head | _]}), do: head |> Map.keys() |> MapSet.new()

  @doc """
  Return a list of all the slots in the stack.
  """
  @spec keys(t) :: MapSet.t(atom)
  def keys(%SlotStack{stack: stack}) do
    stack
    |> Stream.flat_map(&Map.keys/1)
    |> MapSet.new()
  end
end
