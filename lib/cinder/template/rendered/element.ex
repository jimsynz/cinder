defmodule Cinder.Template.Rendered.Element do
  @moduledoc """
  An HTML element.
  """
  defstruct name: nil, attributes: [], children: [], optimised?: false

  alias Cinder.{
    Template.Assigns,
    Template.Compilable,
    Template.Render,
    Template.Rendered.Attribute,
    Template.Rendered.Element,
    Template.Rendered.Static
  }

  @type t :: %Element{
          name: String.t(),
          attributes: [Attribute.t()],
          children: [Render.t()],
          optimised?: boolean
        }

  @type render_result :: iodata | Render.render_list()
  @type render_callback :: (Compilable.t() -> render_result)

  @doc "Initialise a new element of the named tag"
  @spec init(String.t()) :: t
  def init(name), do: %Element{name: name}

  @doc false
  @spec render_head(Element.t(), render_callback()) :: render_result()
  def render_head(element, renderer) when is_function(renderer, 1) do
    if Enum.empty?(element.attributes) do
      ["<", element.name, ">"]
    else
      attributes =
        element.attributes
        |> Stream.intersperse(" ")
        |> Enum.flat_map(fn
          str when is_binary(str) -> [str]
          other -> renderer.(other)
        end)

      [
        "<",
        element.name,
        " ",
        attributes,
        ">"
      ]
    end
  end

  @doc false
  @spec render_body(t, render_callback()) :: render_result()
  def render_body(element, renderer) when is_function(renderer, 1) do
    element.children
    |> Enum.flat_map(renderer)
  end

  @doc false
  @spec render_tail(t) :: iodata
  def render_tail(element) do
    ["</", element.name, ">"]
  end

  defimpl Compilable do
    @doc false
    @spec add_child(Element.t(), Compilable.t(), keyword()) :: Element.t()
    def add_child(element, %Attribute{} = attr, _),
      do: %{element | attributes: [attr | element.attributes]}

    def add_child(element, child, _),
      do: %{element | children: [child | element.children]}

    @doc false
    @spec dynamic?(Element.t()) :: boolean()

    def dynamic?(element),
      do:
        Enum.any?(element.attributes, &Compilable.dynamic?/1) ||
          Enum.any?(element.children, &Compilable.dynamic?/1)

    @doc false
    @spec optimise(Element.t(), Macro.Env.t()) :: Element.t()
    def optimise(element, _env) when element.optimised? == true, do: element

    def optimise(element, env) do
      if dynamic?(element) do
        attributes =
          element.attributes
          |> Enum.reverse()
          |> Enum.map(&Compilable.optimise(&1, env))
          |> Static.optimise_sequences()
          |> List.flatten()
          |> Enum.map(&Compilable.optimise(&1, env))

        children =
          element.children
          |> Enum.reverse()
          |> Enum.map(&Compilable.optimise(&1, env))
          |> Static.optimise_sequences()
          |> List.flatten()
          |> Enum.map(&Compilable.optimise(&1, env))

        %{element | attributes: attributes, children: children, optimised?: true}
      else
        attributes =
          element.attributes
          |> Enum.reverse()
          |> Enum.map(&Compilable.optimise(&1, env))
          |> Static.optimise_sequences()

        children =
          element.children
          |> Enum.map(&Compilable.optimise(&1, env))
          |> Static.optimise_sequences()

        %{element | attributes: attributes, children: children}
        |> Render.render()
        |> Static.init()
        |> Compilable.optimise(env)
        |> List.wrap()
      end
    end
  end

  defimpl Render do
    @doc false
    @spec render(Element.t()) :: Render.render_list()
    def render(element) do
      head = Element.render_head(element, &Render.render/1)
      body = Element.render_body(element, &Render.render/1)
      tail = Element.render_tail(element)

      [head, body, tail]
    end

    @doc false
    @spec execute(Element.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(element, assigns, slots, locals) do
      head = Element.render_head(element, &Render.execute(&1, assigns, slots, locals))
      body = Element.render_body(element, &Render.execute(&1, assigns, slots, locals))
      tail = Element.render_tail(element)

      [head, body, tail]
    end
  end
end
