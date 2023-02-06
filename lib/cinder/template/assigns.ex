defmodule Cinder.Template.Assigns do
  @moduledoc """
  A change tracking assigns implementation with time travelling ability.

  Flux capacitor included.
  """

  defstruct data: %{}, undo: [], redo: [], flux_capacitor: true
  alias Cinder.Template.Assigns

  @behaviour Access

  @meta_keys ~w[context context_modules file function line module]a

  @type key :: atom | binary
  @type value :: any
  @type meta :: list
  @type op :: {:push, key, value, meta} | {:pop, key, meta}

  @type t :: %Assigns{
          data: %{required(key) => value},
          undo: [op],
          redo: [op],
          flux_capacitor: true
        }

  @doc """
  Add a new assignment to the assigns.

  This is a macro rather than a function because it captures information about
  the caller for debugging.
  """
  @spec assign(t, key, value) :: Macro.t()
  defmacro assign(assigns, key, value) do
    meta =
      __CALLER__
      |> Map.take(@meta_keys)
      |> Enum.to_list()

    quote do
      Assigns.push(unquote(assigns), unquote(key), unquote(value), unquote(meta))
    end
  end

  @doc """
  Adds many new assignments to the assigns.

  This is a macro rather than a function because it captures information about
  the caller for debugging.
  """
  @spec assign(t, [{key, value}] | %{required(key) => value}) :: Macro.t()
  defmacro assign(assigns, to_set) do
    meta =
      __CALLER__
      |> Map.take(@meta_keys)
      |> Enum.to_list()

    quote do
      unquote(to_set)
      |> Enum.reduce(unquote(assigns), fn {key, value}, assigns ->
        Assigns.push(assigns, key, value, unquote(meta))
      end)
    end
  end

  @doc """
  Insert a value into the assigns, only if it is not already present.

  This is a macro rather than a function because it captures information about
  the caller for debugging.
  """
  @spec assign_new(t, key, value) :: Macro.t()
  defmacro assign_new(assigns, key, value) do
    meta =
      __CALLER__
      |> Map.take(@meta_keys)
      |> Enum.to_list()

    quote do
      Assigns.push_new(unquote(assigns), unquote(key), unquote(value), unquote(meta))
    end
  end

  @doc false
  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      import Cinder.Template.Assigns, only: [assign: 2, assign: 3, assign_new: 3]
    end
  end

  @doc """
  Initialise a new, empty, assigns.
  """
  @spec init :: t
  def init, do: %Assigns{}

  @doc """
  Initialise a new assigns from a keyword or map.
  """
  @spec init([{key, value}] | %{required(key) => value}) :: t
  def init(assigns) when is_map(assigns) or is_list(assigns), do: assign(init(), assigns)

  @doc """
  Push a new property into the assigns.
  """
  @spec push(t, key, value, meta) :: t
  def push(assigns, key, value, meta \\ [])

  def push(assigns, key, value, meta) when is_atom(key),
    do: push(assigns, to_string(key), value, meta)

  def push(%Assigns{} = assigns, key, value, meta) when is_binary(key) do
    %{
      assigns
      | undo: [{:push, key, value, meta} | assigns.undo],
        data: Map.put(assigns.data, key, value)
    }
  end

  @doc """
  Push a new property into the assigns unless it's key already exists.
  """
  @spec push_new(t, key, value, meta) :: t
  def push_new(assigns, key, value, meta \\ [])

  def push_new(assigns, key, value, meta) when is_atom(key),
    do: push_new(assigns, to_string(key), value, meta)

  def push_new(%Assigns{} = assigns, key, _value, _meta)
      when is_binary(key) and is_map_key(assigns.data, key),
      do: assigns

  def push_new(%Assigns{} = assigns, key, value, meta) when is_binary(key),
    do: push(assigns, key, value, meta)

  @doc """
  Pop a property from the assigns.
  """
  @impl true
  @spec pop(t, key, meta) :: {value, t}
  def pop(assigns, key, meta \\ [])

  def pop(%Assigns{} = assigns, key, meta) when is_atom(key),
    do: pop(assigns, to_string(key), meta)

  def pop(%Assigns{} = assigns, key, meta) when is_binary(key) do
    {value, data} = Map.pop(assigns.data, key)

    {_, data} =
      Enum.reduce_while(assigns.undo, {false, data}, fn
        {:push, ^key, _value, _meta}, {false, data} ->
          {:cont, {true, Map.delete(data, key)}}

        {:push, ^key, value, _meta}, {true, data} ->
          {:halt, {true, Map.put(data, key, value)}}

        _, {found, data} ->
          {:cont, {found, data}}
      end)

    assigns = %{assigns | undo: [{:pop, key, meta} | assigns.undo], data: data}
    {value, assigns}
  end

  @doc """
  Undo a change.
  """
  @spec undo(t) :: {:ok, t} | {:error, any}
  def undo(%Assigns{undo: []}), do: {:error, "No operations to undo"}

  def undo(%Assigns{undo: [{:push, key, _value, _meta} = op | undo], redo: redo} = assigns) do
    Enum.reduce_while(
      undo,
      {:ok, %{assigns | undo: undo, redo: [op | redo], data: Map.delete(assigns.data, key)}},
      fn
        {:push, ^key, value, _meta}, {:ok, assigns} ->
          {:halt, {:ok, %{assigns | data: Map.put(assigns.data, key, value)}}}

        _, {:ok, assigns} ->
          {:cont, {:ok, assigns}}
      end
    )
  end

  def undo(%Assigns{undo: [{:pop, key, _meta} = op | undo], redo: redo} = assigns) do
    Enum.reduce_while(undo, {:ok, %{assigns | undo: undo, redo: [op | redo]}}, fn
      {:push, ^key, value, _meta}, {:ok, assigns} ->
        {:halt, {:ok, %{assigns | data: Map.put(assigns.data, key, value)}}}

      _, {:ok, assigns} ->
        {:cont, {:ok, assigns}}
    end)
  end

  @doc """
  Redo a change.
  """
  @spec redo(t) :: {:ok, t} | {:error, any}
  def redo(%Assigns{redo: []}), do: {:error, "No operations to redo"}

  def redo(%Assigns{undo: undo, redo: [{:push, key, value, _meta} = op | redo]} = assigns),
    do: {:ok, %{assigns | undo: [op | undo], redo: redo, data: Map.put(assigns.data, key, value)}}

  def redo(%Assigns{undo: undo, redo: [{:pop, key, _meta} = op | redo]} = assigns),
    do: {:ok, %{assigns | undo: [op | undo], redo: redo, data: Map.delete(assigns.data, key)}}

  @doc """
  Retrieve any metadata for the most recent operation.
  """
  @spec meta(t) :: list
  def meta(%Assigns{undo: []}), do: []
  def meta(%Assigns{undo: [{:push, _key, _value, meta} | _]}), do: meta
  def meta(%Assigns{undo: [{:pop, _key, meta} | _]}), do: meta

  @doc """
  Fetches the value for the given key from the assigns.
  """
  @impl true
  @spec fetch(t, key) :: {:ok, value} | :error
  def fetch(assigns, key) when is_atom(key), do: fetch(assigns, to_string(key))
  def fetch(%Assigns{data: data}, key), do: Map.fetch(data, key)

  @doc false
  @impl true
  @spec get_and_update(t, key, (value | nil -> {current_value, new_value} | :pop)) ::
          {current_value, t}
        when current_value: value, new_value: value
  def get_and_update(assigns, key, callback) when is_atom(key),
    do: get_and_update(assigns, to_string(key), callback)

  def get_and_update(%Assigns{} = assigns, key, callback)
      when is_binary(key) and is_function(callback, 1) do
    assigns.data
    |> Map.get(key)
    |> callback.()
    |> case do
      :pop -> pop(assigns, key)
      {current_value, new_value} -> {current_value, push(assigns, key, new_value)}
    end
  end

  @doc """
  Does the key appear in the (current) assigns?
  """
  @spec has_key?(t, key) :: boolean
  def has_key?(assigns, key) when is_atom(key), do: has_key?(assigns, to_string(key))
  def has_key?(assigns, key) when is_binary(key), do: Map.has_key?(assigns.data, key)

  defimpl Enumerable do
    def count(assigns), do: Enumerable.Map.count(assigns.data)

    def member?(assigns, {key, value}) when is_atom(key),
      do: member?(assigns, {to_string(key), value})

    def member?(assigns, {key, value}) when is_binary(key),
      do: Enumerable.Map.member?(assigns.data, {key, value})

    def reduce(assigns, acc, fun), do: Enumerable.Map.reduce(assigns.data, acc, fun)

    def slice(assigns), do: Enumerable.Map.slice(assigns.data)
  end
end
