defmodule Cinder.Template.Rendered.Static do
  @moduledoc """
  A static chunk of template.
  """

  defstruct static: []

  alias Cinder.Template.{
    Assigns,
    Compilable,
    Render,
    Rendered.Static
  }

  @type t :: %Static{static: iodata()}

  @spec init(iodata()) :: t
  def init(static), do: %Static{static: static}

  @doc """
  Given a list of nodes, optimise any sequences of more than one static by
  coalescing them into one.
  """
  @spec optimise_sequence([Render.t()]) :: [Render.t()]
  def optimise_sequence(nodes), do: optimise_sequence(nodes, [])
  defp optimise_sequence([], result), do: Enum.reverse(result)

  defp optimise_sequence([%Static{static: next} | remaining], [%Static{static: last} | result]),
    do: optimise_sequence(remaining, [Static.init([next, last]) | result])

  defp optimise_sequence([next | remaining], result),
    do: optimise_sequence(remaining, [next | result])

  defimpl Compilable do
    @doc false
    @spec add_child(Static.t(), any, any) :: Static.t()
    def add_child(node, _, _), do: node

    @spec dynamic?(Static.t()) :: false
    def dynamic?(_), do: false

    @spec optimise(Static.t(), Macro.Env.t()) :: Static.t()
    def optimise(node, _env), do: node
  end

  defimpl Render do
    @doc false
    @spec render(Static.t()) :: Render.render_list()
    def render(node), do: node.static

    @doc false
    @spec execute(Static.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(node, _assigns, _slots, _locals), do: node.static
  end
end
