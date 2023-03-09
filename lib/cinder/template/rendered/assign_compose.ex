defmodule Cinder.Template.Rendered.AssignCompose do
  @moduledoc """
  A wrapper around a renderable that allows you to inject assigns as a specific
  location in the tree.
  """
  defstruct assigns: nil, renderable: nil

  alias Cinder.Template.{Assigns, Render, Rendered.AssignCompose, SlotStack}

  @type t :: %AssignCompose{
          assigns: Assigns.t(),
          renderable: Render.t()
        }

  @doc "Initialise a assign composition"
  @spec init(Render.t(), Assigns.t()) :: t
  def init(renderable, assigns), do: %AssignCompose{renderable: renderable, assigns: assigns}

  defimpl Render do
    require Assigns

    @doc false
    @spec render(AssignCompose.t()) :: Render.render_list()
    def render(compose), do: Render.render(compose.renderable)

    @doc false
    @spec execute(AssignCompose.t(), Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata
    def execute(compose, _assigns, slots, locals),
      do: Render.execute(compose.renderable, compose.assigns, slots, locals)
  end
end
