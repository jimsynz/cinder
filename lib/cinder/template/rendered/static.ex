defmodule Cinder.Template.Rendered.Static do
  @moduledoc """
  A static chunk of template.
  """

  defstruct static: []

  alias Cinder.Template.{
    Assigns,
    Compilable,
    Iodata,
    Render,
    Rendered.Static,
    SlotStack
  }

  @type t :: %Static{static: iodata()}

  @spec init(iodata()) :: t
  def init(static), do: %Static{static: static}

  @doc """
  Given a list of nodes, optimise any sequences of more than one static by
  coalescing them into one.
  """
  @spec optimise_sequences([Render.t()]) :: [Render.t()]
  def optimise_sequences(nodes) do
    nodes
    |> List.flatten()
    |> optimise_sequences([])
  end

  @doc """
  Is the static empty of content?
  """
  @spec empty?(t) :: boolean
  def empty?(static) when static.static == [], do: true
  def empty?(static) when static.static == <<>>, do: true
  def empty?(_static), do: false

  @doc """
  Trim any leading whitespace from the static.
  """
  @spec trim_leading(t) :: t
  def trim_leading(static),
    do: %{
      static
      | static: static.static |> Iodata.stream() |> Iodata.trim_leading() |> Enum.to_list()
    }

  @doc """
  Trim any trailing whitespace from the static.
  """
  @spec trim_trailing(t) :: t
  def trim_trailing(static),
    do: %{
      static
      | static: static.static |> Iodata.stream() |> Iodata.trim_trailing() |> Enum.to_list()
    }

  defp optimise_sequences([], result), do: Enum.reverse(result)

  defp optimise_sequences([%Static{static: []} | remaining], result),
    do: optimise_sequences(remaining, result)

  defp optimise_sequences([%Static{static: next} | remaining], [%Static{static: last} | result]),
    do: optimise_sequences(remaining, [Static.init([next, last]) | result])

  defp optimise_sequences([next | remaining], result),
    do: optimise_sequences(remaining, [next | result])

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
    @spec execute(Static.t(), Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata
    def execute(node, _assigns, _slots, _locals), do: node.static
  end
end
