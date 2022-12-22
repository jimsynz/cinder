defmodule Cinder.Template.Engine do
  @moduledoc false
  @behaviour EEx.Engine

  @impl true
  defdelegate init(opts), to: EEx.Engine

  @impl true
  defdelegate handle_body(state), to: EEx.Engine

  @impl true
  defdelegate handle_begin(state), to: EEx.Engine

  @impl true
  defdelegate handle_end(state), to: EEx.Engine

  @impl true
  defdelegate handle_text(state, meta, text), to: EEx.Engine

  @impl true
  def handle_expr(state, marker, expr) do
    expr =
      expr
      |> Macro.prewalk(&handle_yield/1)
      |> Macro.prewalk(&EEx.Engine.handle_assign/1)

    EEx.Engine.handle_expr(state, marker, expr)
  end

  defp handle_yield({:yield, _, [slot_name]}) when is_atom(slot_name) do
    quote do
      Access.get(@slots, unquote(slot_name))
    end
  end

  defp handle_yield({:yield, _, _}) do
    quote do
      Access.get(@slots, :default)
    end
  end

  defp handle_yield(ast), do: ast
end
