defmodule Cinder.Template.Rendered.Expression do
  @moduledoc """
  A Handlebars expression to be interpreted into the template.
  """
  defstruct expr: nil, optimised?: false

  alias Cinder.{
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.HtmlEscaper,
    Template.Render,
    Template.Rendered.Expression,
    Template.SlotStack
  }

  @type t :: %Expression{
          expr: nil | Macro.t() | Template.renderer(),
          optimised?: boolean
        }

  @doc "Initialise an expression containing the given Elixir AST"
  @spec init(Macro.t()) :: t
  def init(expr), do: %Expression{expr: expr}

  defimpl Compilable do
    @doc false
    @spec add_child(Expression.t(), any, any) :: Expression.t()
    def add_child(expr, _, _), do: expr

    @doc false
    @spec dynamic?(Expression.t()) :: true
    def dynamic?(_), do: true

    @doc false
    @spec optimise(Expression.t(), Macro.Env.t()) :: Expression.t()
    def optimise(expr, _env) when expr.optimised? == true, do: expr

    def optimise(expr, env) do
      inner = expr.expr

      fun =
        quote context: env.module, generated: true do
          fn assigns, slots, locals ->
            unquote(inner)
            |> to_string()
            |> HtmlEscaper.escape()
          end
        end

      %{expr | expr: fun, optimised?: true}
    end
  end

  defimpl Render do
    @doc false
    @spec render(Expression.t()) :: Render.render_list()
    def render(_expr), do: [:expr]

    @doc false
    @spec execute(Expression.t(), Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata
    def execute(expr, assigns, slots, locals), do: expr.expr.(assigns, slots, locals)
  end
end
