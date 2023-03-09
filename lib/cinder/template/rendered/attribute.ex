defmodule Cinder.Template.Rendered.Attribute do
  @moduledoc """
  An HTML attribute.
  """

  defstruct name: nil, optimised?: false, value: nil

  alias Cinder.{
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.HtmlEscaper,
    Template.Render,
    Template.Rendered.Attribute,
    Template.SlotStack
  }

  @type t :: %Attribute{
          name: binary,
          optimised?: boolean,
          value: nil | binary | Macro.t() | Template.renderer()
        }

  @doc false
  @spec init(binary, binary | Macro.t()) :: t
  def init(name, value), do: %Attribute{name: name, value: value}

  defimpl Compilable do
    @doc false
    @spec add_child(Attribute.t(), Compilable.t(), keyword) :: Attribute.t()
    def add_child(node, _, _), do: node

    @doc false
    @spec dynamic?(Attribute.t()) :: boolean
    def dynamic?(attribute) when is_binary(attribute.value), do: false
    def dynamic?(_), do: true

    @doc false
    @spec optimise(Attribute.t(), Macro.Env.t()) :: Attribute.t()
    def optimise(attribute, _env) when attribute.optimised? == true, do: attribute

    def optimise(attribute, _env) when is_binary(attribute.value),
      do: %{attribute | optimised?: true}

    def optimise(attribute, env) do
      fun =
        quote context: env.module, generated: true do
          fn assigns, slots, locals ->
            value =
              unquote(attribute.value)
              |> then(fn
                nil -> []
                fun when is_function(fun, 3) -> fun.(assigns, slots, locals)
                other -> [other]
              end)
              |> HtmlEscaper.escape()

            [unquote(attribute.name), "=", ?", value, ?"]
          end
        end

      %{attribute | value: fun, optimised?: true}
    end
  end

  defimpl Render do
    @doc false
    @spec render(Attribute.t()) :: Render.render_list()
    def render(attribute) when is_nil(attribute.value), do: [attribute.name]

    def render(attribute) when is_binary(attribute.value) do
      [attribute.name, "=", ?", HtmlEscaper.escape(attribute.value), ?"]
    end

    def render(attribute) do
      [attribute.name, "=", :expr]
    end

    @doc false
    @spec execute(Attribute.t(), Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata()
    def execute(attribute, assigns, slots, locals) when is_function(attribute.value, 3),
      do: attribute.value.(assigns, slots, locals)

    def execute(attribute, _, _, _), do: render(attribute)
  end
end
