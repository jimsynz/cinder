defmodule Cinder.Template.Rendered.LocalCompose do
  @moduledoc """
  A wrapper around a renderable that allows you to inject locals.
  """
  defstruct locals: [], renderable: nil

  alias Cinder.Template.{
    Assigns,
    Render,
    Rendered.LocalCompose,
    SlotStack
  }

  @type t :: %LocalCompose{
          locals: [{Assigns.key(), Assigns.value()}],
          renderable: Render.t()
        }

  @doc "Initialise a local composition"
  def init(renderable, locals) when is_map(locals) or is_list(locals),
    do: %LocalCompose{renderable: renderable, locals: locals}

  defimpl Render do
    require Assigns

    @doc false
    @spec render(LocalCompose.t()) :: Render.render_list()
    def render(compose), do: Render.render(compose.renderable)

    @doc false
    @spec execute(LocalCompose.t(), Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata()
    def execute(compose, assigns, slots, locals) do
      locals = Assigns.assign(locals, compose.locals)
      Render.execute(compose.renderable, assigns, slots, locals)
    end
  end
end
