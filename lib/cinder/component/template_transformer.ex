defmodule Cinder.Component.TemplateTransformer do
  @moduledoc """
  Transforms a compiled template to add extra attributes to the root element as
  needed for components to work as expected.
  """

  alias Cinder.{
    Component.Dsl.Info,
    Errors.Component.RootElementError,
    Errors.Template.UnknownAssignError,
    Template.Compilable,
    Template.Rendered.Attribute,
    Template.Rendered.Document,
    Template.Rendered.Element,
    Template.Rendered.Static,
    Template.Rendered.VoidElement
  }

  alias Spark.{Dsl, Dsl.Transformer}

  @doc "Given a Spark DSL map and a template, attempt to transform it into a component"
  @spec transform_template(Dsl.t(), Document.t()) :: Document.t() | no_return
  def transform_template(dsl_state, document) when is_struct(document, Document) do
    case document.children do
      [element]
      when is_struct(element, Element) or is_struct(element, VoidElement) ->
        element = transform_element(dsl_state, element)
        %{document | children: [element]}

      [static] when is_struct(static, Static) ->
        document

      _ ->
        raise RootElementError,
          component: Transformer.get_persisted(dsl_state, :module),
          file: document.file,
          line: document.line,
          column: document.column
    end
  end

  defp transform_element(dsl_state, element) do
    module = Transformer.get_persisted(dsl_state, :module)

    attributes =
      dsl_state
      |> Info.properties()
      |> Stream.filter(& &1.data?)
      |> Stream.map(& &1.name)
      |> Stream.map(&prop_name_to_access_attribute(&1, module))
      |> Stream.concat([
        Attribute.init(
          "data-cinder-component",
          Transformer.get_persisted(dsl_state, :script_class_name)
        )
      ])
      |> Stream.concat(element.attributes)
      |> Enum.map(&Compilable.optimise(&1, __ENV__))

    %{element | attributes: attributes}
  end

  defp prop_name_to_access_attribute(prop_name, module) do
    name = "data_#{prop_name}" |> String.replace(~r/_+/, "-")

    value =
      quote context: module, generated: true do
        fn assigns, _slots, _locals ->
          case Access.fetch(assigns, unquote(prop_name)) do
            {:ok, value} ->
              to_string(value)

            :error ->
              raise UnknownAssignError,
                assign: unquote(prop_name),
                file: __ENV__.file,
                line: __ENV__.line
          end
        end
      end

    Attribute.init(name, value)
  end
end
