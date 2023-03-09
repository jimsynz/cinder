defmodule Cinder.Template do
  alias Cinder.Template.{Assigns, Render}

  @moduledoc """
  Mixins for embedding templates in modules.
  """

  @type assigns :: Assigns.t()
  @type locals :: Assigns.t()
  @type renderer :: (assigns, slots, locals -> Render.t())
  @type slots :: %{required(atom) => renderer}

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      import Cinder.Template.Assigns, only: :macros
      import Cinder.Template.Helpers.Block
      import Cinder.Template.Helpers.Expression
      import Cinder.Template.Helpers.Route
      import Cinder.Template.Macros
    end
  end

  @doc false
  @spec hash(Path.t()) :: binary | nil
  # sobelow_skip ["Traversal.FileModule"]
  def hash(path) do
    if File.exists?(path) do
      contents = File.read!(path)
      md5 = :erlang.md5(path <> contents)

      <<1>> <> md5
    else
      md5 = :erlang.md5(path)

      <<0>> <> md5
    end
  end
end
