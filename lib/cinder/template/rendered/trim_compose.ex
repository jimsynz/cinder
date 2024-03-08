defmodule Cinder.Template.Rendered.TrimCompose do
  @moduledoc """
  A wrapper around a renderable that removes any leading and trailing
  whitespace.
  """

  defstruct renderable: nil

  alias Cinder.Template.{Assigns, Iodata, Render, Rendered.TrimCompose, SlotStack}

  @type t :: %TrimCompose{
          renderable: Render.t()
        }

  @doc "Initialise a trim composition"
  @spec init(Render.t()) :: t
  def init(renderable), do: %TrimCompose{renderable: renderable}

  defimpl Render do
    @doc false
    @spec render(TrimCompose.t()) :: Render.render_list()
    def render(compose), do: Render.render(compose.renderable)

    @doc false
    @spec execute(TrimCompose.t(), Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata
    def execute(compose, assigns, slots, locals) do
      compose.renderable
      |> Render.execute(assigns, slots, locals)
      |> Iodata.stream()
      |> Iodata.trim_leading()
      |> Iodata.trim_trailing()
      |> Enum.to_list()
    end
  end
end
