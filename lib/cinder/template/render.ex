defprotocol Cinder.Template.Render do
  @moduledoc """
  A protocol for rendering compiled templates.
  """

  alias Cinder.Template.{Assigns, SlotStack}

  @type render_list :: iolist | [atom | {atom, render_list}]

  @doc """
  Render a template into it's static parts.

  Items with dynamic content will inject a keyword list labeling any dynamic parts.
  """
  @spec render(t) :: render_list
  def render(compiled)

  @doc """
  Execute a template (ie render it) including any dynamic content with the data
  provided.
  """
  @spec execute(t, Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata
  def execute(compiled, assigns, slots, locals)
end

defimpl Cinder.Template.Render, for: List do
  @moduledoc false
  alias Cinder.Template.{Assigns, Render, SlotStack}

  @doc false
  @spec render([Render.t()]) :: Render.render_list()
  def render(list) do
    Enum.map(list, fn
      node when is_map(node) -> Render.render(node)
      list when is_list(list) -> Render.render(list)
      binary when is_binary(binary) -> binary
      character when is_integer(character) and character >= 0 -> character
    end)
  end

  @doc false
  @spec execute([Render.t()], Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata
  def execute(list, assigns, slots, locals) do
    Enum.map(list, fn
      node when is_map(node) -> Render.execute(node, assigns, slots, locals)
      list when is_list(list) -> Render.execute(list, assigns, slots, locals)
      binary when is_binary(binary) -> binary
      character when is_integer(character) and character >= 0 -> character
    end)
  end
end
