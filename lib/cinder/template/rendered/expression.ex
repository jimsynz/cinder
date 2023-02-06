defmodule Cinder.Template.Rendered.Expression do
  @moduledoc """
  A Handlebars expression to be interpreted into the template.
  """
  defstruct expr: nil

  alias Cinder.{
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.HtmlEscaper,
    Template.Render,
    Template.Rendered.Expression
  }

  @type t :: %Expression{
          expr: nil | Macro.t() | Template.renderer()
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
    def optimise(expr, _env) when is_function(expr.expr, 3), do: expr

    def optimise(%{expr: {:fn, _, _}} = expr, _env), do: expr

    def optimise(expr, env) do
      fun =
        quote context: env.module, generated: true do
          fn assigns, slots, locals ->
            unquote(expr.expr)
            |> to_string()
            |> HtmlEscaper.escape()
          end
        end

      %{expr | expr: fun}
    end
  end

  defimpl Render do
    @doc false
    @spec render(Expression.t()) :: Render.render_list()
    def render(_expr), do: [:expr]

    @doc false
    @spec execute(Expression.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(expr, assigns, slots, locals), do: expr.expr.(assigns, slots, locals)
  end
end
