defmodule Cinder.Template.Rendered.Document do
  @moduledoc """
  An HTML document.
  """
  defstruct args: [],
            children: [],
            column: 1,
            file: nil,
            line: 1,
            merge_locals: nil,
            optimised?: false

  alias Cinder.{
    Template.Assigns,
    Template.Compilable,
    Template.Render,
    Template.Rendered.Document,
    Template.Rendered.Static,
    Template.SlotStack
  }

  @type t :: %Document{
          args: Keyword.t(any),
          children: [Render.t()],
          column: non_neg_integer(),
          file: String.t(),
          line: non_neg_integer(),
          merge_locals: nil | (Assigns.t() -> Assigns.t()),
          optimised?: boolean
        }

  @doc false
  @spec init(keyword) :: t
  def init(attrs), do: struct(Document, attrs)

  defimpl Compilable do
    @doc false
    @spec add_child(Document.t(), Compilable.t(), keyword) :: Document.t()
    def add_child(document, node, _), do: %{document | children: [node | document.children]}

    @doc false
    @spec dynamic?(Document.t()) :: boolean
    def dynamic?(document), do: Enum.any?(document.children, &Compilable.dynamic?/1)

    @spec optimise(Document.t(), Macro.Env.t()) :: Document.t() | Static.t()
    def optimise(document, _env) when document.optimised? == true, do: document

    def optimise(document, env) do
      children =
        document.children
        |> trim_leading_whitespace()
        |> Enum.reverse()
        |> Enum.map(&Compilable.optimise(&1, env))
        |> Static.optimise_sequences()
        |> Enum.map(&Compilable.optimise(&1, env))
        |> trim_trailing_whitespace()
        |> Enum.map(&Compilable.optimise(&1, env))
        |> Static.optimise_sequences()

      fun =
        quote context: env.module, generated: true do
          fn locals ->
            unquote(document.args)
            |> Enum.reduce(locals, fn {key, value}, locals ->
              Assigns.push(locals, key, value)
            end)
          end
        end

      %{document | children: children, merge_locals: fun, optimised?: true}
    end

    defp trim_leading_whitespace(children), do: trim_statics(children, &Static.trim_leading/1)
    defp trim_trailing_whitespace(children), do: trim_statics(children, &Static.trim_trailing/1)

    defp trim_statics(children, trimmer) do
      children
      |> Enum.reduce({[], false}, fn
        node, {result, false} when is_struct(node, Static) ->
          static = trimmer.(node)

          if Static.empty?(static) do
            {result, false}
          else
            {[static | result], true}
          end

        node, {result, false} ->
          {[node | result], true}

        node, {result, true} ->
          {[node | result], true}
      end)
      |> elem(0)
      |> Enum.reverse()
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
    @spec execute(Document.t(), Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata
    def execute(document, assigns, slots, locals) do
      locals = document.merge_locals.(locals)

      for child <- document.children do
        Render.execute(child, assigns, slots, locals)
      end
    end
  end
end
