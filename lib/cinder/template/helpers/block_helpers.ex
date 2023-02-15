defmodule Cinder.Template.Helpers.Block do
  @moduledoc """
  The built-in block helpers.
  """
  alias Cinder.Template.{Render, Rendered.LocalCompose}
  import Cinder.Template.Macros

  # Things that Handlebars considers falsy.
  @falsy [nil, false, "", [], 0]

  @doc """
  Called when the `#if` block is executed.
  """
  @spec block_if(any, keyword) :: Render.t()
  def block_if(condition, opts \\ [])

  def block_if(0, opts) do
    if Keyword.get(opts, :includeZero) == true do
      ~B"{{yield 'positive'}}"
    else
      ~B"{{yield 'negative'}}"
    end
  end

  def block_if(condition, _opts) when condition in @falsy do
    ~B"{{yield 'negative'}}"
  end

  def block_if(_condition, _opts) do
    ~B"{{yield 'positive'}}"
  end

  @doc """
  Called when the `#unless` block is executed.
  """
  @spec block_unless(any, keyword) :: Render.t()
  def block_unless(condition, opts \\ [])

  def block_unless(0, opts) do
    if Keyword.get(opts, :includeZero) == true do
      ~B"{{yield 'negative'}}"
    else
      ~B"{{yield 'positive'}}"
    end
  end

  def block_unless(condition, _opts) when condition in @falsy do
    ~B"{{yield 'positive'}}"
  end

  def block_unless(_condition, _opts) do
    ~B"{{yield 'negative'}}"
  end

  @doc """
  Iterates over each element of an enumerable and yields for each.
  """
  @spec each(Enum.t()) :: Render.t()
  def each(collection, bindings \\ [:this])

  def each(collection, [local]) do
    Enum.map(collection, fn element ->
      ~B"{{yield 'positive'}}"
      |> LocalCompose.init([{local, element}])
    end)
  end
end
