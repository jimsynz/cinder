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
      ~HB"{{yield 'positive'}}"
    else
      ~HB"{{yield 'negative'}}"
    end
  end

  def block_if(condition, opts) when condition in @falsy do
    ~HB"{{yield 'negative'}}"
  end

  def block_if(condition, opts) do
    ~HB"{{yield 'positive'}}"
  end

  @doc """
  Called when the `#unless` block is executed.
  """
  @spec block_unless(any, keyword) :: Render.t()
  def block_unless(condition, opts \\ [])

  def block_unless(0, opts) do
    if Keyword.get(opts, :includeZero) == true do
      ~HB"{{yield 'negative'}}"
    else
      ~HB"{{yield 'positive'}}"
    end
  end

  def block_unless(condition, opts) when condition in @falsy do
    ~HB"{{yield 'positive'}}"
  end

  def block_unless(condition, opts) do
    ~HB"{{yield 'negative'}}"
  end

  @doc """
  Iterates over each element of an enumerable and yields for each.
  """
  @spec each(Enum.t()) :: Render.t()
  def each(collection, bindings \\ [:this])

  def each(collection, [local]) do
    Enum.map(collection, fn element ->
      ~HB"{{yield 'positive'}}"
      |> LocalCompose.init([{local, element}])
    end)
  end
end
