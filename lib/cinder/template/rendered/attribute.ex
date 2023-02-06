defmodule Cinder.Template.Rendered.Attribute do
  @moduledoc """
  An HTML attribute.
  """

  defstruct name: nil, value: nil

  alias Cinder.{
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.HtmlEscaper,
    Template.Render,
    Template.Rendered.Attribute
  }

  @type t :: %Attribute{
          name: binary,
          value: nil | binary | Macro.t() | Template.renderer()
        }

  @doc false
  @spec init(binary, binary) :: t
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
    def optimise(attribute, _env) when is_function(attribute.value, 3), do: attribute

    def optimise(%{value: {:fn, _, _}} = attribute, _env), do: attribute

    def optimise(attribute, env) when is_binary(attribute.value) do
      fun =
        quote context: env.module, generated: true do
          fn _assigns, _slots, _locals ->
            [unquote(attribute.name), "=", ?", HtmlEscaper.escape(unquote(attribute.value)), ?"]
          end
        end

      %{attribute | value: fun}
    end

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

      %{attribute | value: fun}
    end
  end

  defimpl Render do
    @doc false
    @spec render(Attribute.t()) :: Render.render_list()
    def render(attribute) when is_binary(attribute.value) do
      [attribute.name, "=", ?", HtmlEscaper.escape(attribute.value), ?"]
    end

    def render(attribute) do
      [attribute.name, "=", :expr]
    end

    @doc false
    @spec execute(Attribute.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata()
    def execute(attribute, assigns, slots, locals) do
      attribute.value.(assigns, slots, locals)
    end
  end
end
