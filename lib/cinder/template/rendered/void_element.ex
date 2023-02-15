defmodule Cinder.Template.Rendered.VoidElement do
  @moduledoc """
  A void HTML element.
  """
  defstruct name: nil, attributes: [], optimised?: false

  alias Cinder.{
    Template.Assigns,
    Template.Compilable,
    Template.Render,
    Template.Rendered.Attribute,
    Template.Rendered.Static,
    Template.Rendered.VoidElement
  }

  @type t :: %VoidElement{
          name: String.t(),
          attributes: [Attribute.t()],
          optimised?: boolean
        }

  @type render_result :: iodata | Render.render_list()
  @type render_callback :: (Compilable.t() -> render_result)

  @doc "Initialise a new void element of the named tag"
  @spec init(String.t()) :: t
  def init(name), do: %VoidElement{name: name}

  @doc false
  @spec render(VoidElement.t(), render_callback) :: render_result
  def render(element, renderer) when is_function(renderer, 1) do
    attributes =
      element.attributes
      |> Stream.intersperse(" ")
      |> Enum.flat_map(fn
        str when is_binary(str) -> [str]
        other -> renderer.(other)
      end)

    if Enum.any?(attributes) do
      ["<", element.name, " ", attributes, " />"]
    else
      ["<", element.name, " />"]
    end
  end

  defimpl Compilable do
    @doc false
    @spec add_child(VoidElement.t(), Attribute.t(), any) :: VoidElement.t()
    def add_child(element, %Attribute{} = attr, _),
      do: %{element | attributes: [attr | element.attributes]}

    @doc false
    @spec dynamic?(VoidElement.t()) :: boolean
    def dynamic?(element),
      do: Enum.any?(element.attributes, &Compilable.dynamic?/1)

    @doc false
    @spec optimise(VoidElement.t(), Macro.Env.t()) :: VoidElement.t()
    def optimise(element, _env) when element.optimised? == true, do: element

    def optimise(element, env) do
      if dynamic?(element) do
        attributes =
          element.attributes
          |> Enum.reverse()
          |> Enum.map(&Compilable.optimise(&1, env))

        %{element | attributes: attributes, optimised?: true}
      else
        element
        |> Render.render()
        |> Static.init()
        |> Compilable.optimise(env)
      end
    end
  end

  defimpl Render do
    @doc false
    @spec render(VoidElement.t()) :: Render.render_list()
    def render(element),
      do: VoidElement.render(element, &Render.render/1)

    @doc false
    @spec execute(VoidElement.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(element, assigns, slots, locals),
      do: VoidElement.render(element, &Render.execute(&1, assigns, slots, locals))
  end
end
