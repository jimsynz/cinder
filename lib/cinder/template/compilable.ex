defprotocol Cinder.Template.Compilable do
  @moduledoc """
  Protocol for manipulating template AST.
  """

  @doc """
  Add a child node to the node if possible.
  """
  @spec add_child(t, t, keyword) :: t
  def add_child(parent, child, opts \\ [])

  @doc """
  Optimise if possible.
  """
  @spec optimise(t, Macro.Env.t()) :: t
  def optimise(node, env)

  @doc """
  Does this node contain any dynamic segments?
  """
  @spec dynamic?(t) :: boolean
  def dynamic?(node)
end
