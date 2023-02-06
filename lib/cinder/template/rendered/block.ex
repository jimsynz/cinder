defmodule Cinder.Template.Rendered.Block do
  @moduledoc """
  A Handlebars block.
  """

  defstruct expr: nil, positive: [], negative: [], bindings: []

  alias Cinder.{
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.Macros,
    Template.Render,
    Template.Rendered.Block,
    Template.Rendered.Static
  }

  @type t :: %Block{
          expr: nil | Macro.t() | Template.renderer(),
          positive: [Render.t()],
          negative: [Render.t()],
          bindings: [atom]
        }

  @doc "Initialise an empty block containing the given Elixir AST"
  @spec init(Macro.t()) :: t
  def init(expr), do: %Block{expr: expr}

  defimpl Compilable do
    import Cinder.Template.Assigns

    @doc false
    @spec add_child(Block.t(), Render.t(), keyword) :: Block.t()
    def add_child(block, child, stage: :positive),
      do: %{block | positive: [child | block.positive]}

    def add_child(block, child, stage: :negative),
      do: %{block | negative: [child | block.negative]}

    @doc false
    @spec dynamic?(Block.t()) :: boolean
    def dynamic?(_), do: true

    @doc false
    @spec optimise(Block.t(), Macro.Env.t()) :: Block.t()
    def optimise(node, _env) when is_function(node.expr, 3), do: node

    def optimise(%{expr: {:fn, _, _}} = node, _env), do: node

    def optimise(node, env) do
      positive =
        if Enum.any?(node.positive, &Compilable.dynamic?/1) do
          node.positive
          |> Enum.reverse()
          |> Enum.map(&Compilable.optimise(&1, env))
          |> Static.optimise_sequence()
        else
          node.positive
          |> Enum.reverse()
          |> Enum.map(&Render.render/1)
          |> Static.init()
          |> List.wrap()
        end

      negative =
        if Enum.any?(node.negative, &Compilable.dynamic?/1) do
          node.negative
          |> Enum.reverse()
          |> Enum.map(&Compilable.optimise(&1, env))
          |> Static.optimise_sequence()
        else
          node.negative
          |> Enum.reverse()
          |> Enum.map(&Render.render/1)
          |> Static.init()
          |> List.wrap()
        end

      node = %{node | positive: positive, negative: negative}

      fun =
        quote context: env.module, generated: true do
          fn assigns, slots, locals ->
            slots =
              slots
              |> assign("positive", unquote(Macros.escape(positive)))
              |> assign("negative", unquote(Macros.escape(negative)))

            unquote(node.expr)
            |> Render.execute(assigns, slots, locals)
          end
        end

      %{node | expr: fun}
    end
  end

  defimpl Render do
    @doc false
    @spec render(Block.t()) :: Render.render_list()
    def render(node) do
      [positive: Render.render(node.positive), negative: Render.render(node.negative)]
    end

    @doc false
    @spec execute(Block.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(block, assigns, slots, locals), do: block.expr.(assigns, slots, locals)
  end
end
