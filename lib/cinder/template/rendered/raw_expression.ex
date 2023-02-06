defmodule Cinder.Template.Rendered.RawExpression do
  @moduledoc """
  A Handlebars expression to be interpreted into the template.
  """
  defstruct expr: nil

  alias Cinder.{
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.Render,
    Template.Rendered.RawExpression
  }

  @type t :: %RawExpression{
          expr: nil | Macro.t() | Template.renderer()
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
    def optimise(expr, _env) when is_function(expr.expr, 3), do: expr

    def optimise(%{expr: {:fn, _, _}} = expr, _env), do: expr

    def optimise(expr, env) do
      fun =
        quote context: env.module, generated: true do
          fn assigns, slots, locals ->
            unquote(expr.expr)
          end
        end

      %{expr | expr: fun}
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
