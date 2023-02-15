defmodule Cinder.Template.Rendered.RawExpression do
  @moduledoc """
  A Handlebars expression to be interpreted into the template.
  """
  defstruct expr: nil, optimised?: false

  alias Cinder.{
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.Render,
    Template.Rendered.RawExpression
  }

  @type t :: %RawExpression{
          expr: nil | Macro.t() | Template.renderer(),
          optimised?: boolean
        }

  @doc "Initialise an expression containing the given Elixir AST"
  @spec init(Macro.t()) :: t
  def init(expr), do: %RawExpression{expr: expr}

  defimpl Compilable do
    @doc false
    @spec add_child(RawExpression.t(), any, any) :: RawExpression.t()
    def add_child(expr, _, _), do: expr

    @doc false
    @spec dynamic?(RawExpression.t()) :: true
    def dynamic?(_), do: true

    @doc false
    @spec optimise(RawExpression.t(), Macro.Env.t()) :: RawExpression.t()
    def optimise(expr, _env) when expr.optimised? == true, do: expr

    def optimise(expr, env) do
      inner = expr.expr

      fun =
        quote context: env.module, generated: true do
          fn assigns, slots, locals ->
            unquote(inner)
          end
        end

      %{expr | expr: fun, optimised?: true}
    end
  end

  defimpl Render do
    @doc false
    @spec render(RawExpression.t()) :: Render.render_list()
    def render(_expr), do: [:expr]

    @doc false
    @spec execute(RawExpression.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(expr, assigns, slots, locals), do: expr.expr.(assigns, slots, locals)
  end
end
