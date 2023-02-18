defmodule Cinder.Template.Rendered.SlotCompose do
  @moduledoc """
  A wrapper around a renderable that allows for easy composition of slots.
  """
  defstruct name: nil, renderable: nil, slot: nil

  alias Cinder.Template.{Assigns, Render, Rendered.SlotCompose}

  @type t :: %SlotCompose{
          name: atom | binary,
          renderable: Render.t(),
          slot: Render.t()
        }

  @doc "Initialise a slot composition"
  @spec init(Render.t(), Render.t(), atom | binary) :: t
  def init(renderable, slot, slot_name \\ :default),
    do: %SlotCompose{renderable: renderable, slot: slot, name: slot_name}

  defimpl Render do
    require Assigns

    @doc false
    @spec render(SlotCompose.t()) :: Render.render_list()
    def render(compose), do: Render.render(compose.renderable)

    @doc false
    @spec execute(SlotCompose.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(compose, assigns, slots, locals) do
      slots = Assigns.assign(slots, compose.name, compose.slot)
      Render.execute(compose.renderable, assigns, slots, locals)
    end
  end
end
