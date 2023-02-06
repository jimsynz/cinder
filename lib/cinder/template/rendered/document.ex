defmodule Cinder.Template.Rendered.Document do
  @moduledoc """
  An HTML document.
  """
  defstruct file: nil, line: 1, column: 1, children: [], renderer: nil, args: []

  alias Cinder.{
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.Macros,
    Template.Render,
    Template.Rendered.Document,
    Template.Rendered.Static
  }

  @type t :: %Document{
          file: String.t(),
          line: non_neg_integer(),
          column: non_neg_integer(),
          children: [Render.t()],
          renderer: Template.renderer() | nil,
          args: Keyword.t(any)
        }

  defimpl Compilable do
    @doc false
    @spec add_child(Document.t(), Compilable.t(), keyword) :: Document.t()
    def add_child(document, node, _), do: %{document | children: [node | document.children]}

    @doc false
    @spec dynamic?(Document.t()) :: boolean
    def dynamic?(document), do: Enum.any?(document.children, &Compilable.dynamic?/1)

    @spec optimise(Document.t(), Macro.Env.t()) :: Document.t() | Static.t()
    def optimise(document, _env) when is_function(document.renderer, 3), do: document

    def optimise(%{renderer: {:fn, _, _}} = document, _env), do: document

    def optimise(document, env) do
      children =
        document.children
        |> Enum.reverse()
        |> Enum.map(&Compilable.optimise(&1, env))
        |> Static.optimise_sequence()

      fun =
        quote context: env.module, generated: true do
          fn assigns, slots, locals ->
            locals = assign(locals, unquote(document.args))

            for child <- unquote(Macros.escape(children)) do
              Render.execute(child, assigns, slots, locals)
            end
          end
        end

      %{document | children: children, renderer: fun}
    end
  end

  defimpl Render do
    @doc false
    @spec render(Document.t()) :: Render.render_list()
    def render(document) do
      document.children
      |> Enum.map(&Render.render/1)
    end

    @doc false
    @spec execute(Document.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(document, assigns, slots, locals), do: document.renderer.(assigns, slots, locals)
  end
end
