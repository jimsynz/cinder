defmodule Cinder.Template do
  alias Cinder.Template.{Assigns, Render}
  @moduledoc false

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
      path
      |> File.read!()
      |> :erlang.md5()
    end
  end
end
