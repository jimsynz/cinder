defmodule Cinder.Component.Dsl.Transformer do
  @moduledoc false

  alias Cinder.Request

  alias Cinder.Component.{
    Dsl.Event,
    Dsl.Property,
    Dsl.Slot,
    PropType,
    Script,
    TemplateTransformer
  }

  alias Cinder.Template.Macros
  alias Spark.{Dsl, Dsl.Transformer, Error.DslError}
  use Transformer

  require EEx

  EEx.function_from_file(
    :def,
    :javascript_generator,
    Path.expand("./component.js.eex", __DIR__),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :typescript_generator,
    Path.expand("./component.ts.eex", __DIR__),
    [:assigns]
  )

  @doc false
  @impl true
  @spec after?(module) :: boolean
  def after?(_), do: false

  @doc false
  @impl true
  @spec before?(module) :: boolean
  def before?(_), do: false

  @doc false
  @impl true
  @spec transform(Dsl.t()) :: {:ok, Dsl.t()}
  def transform(dsl_state) do
    with :ok <- validate_event_scripts(dsl_state),
         {:ok, dsl_state} <- build_property_schema(dsl_state),
         {:ok, dsl_state} <- build_slot_schema(dsl_state),
         {:ok, dsl_state} <- build_script_class_name(dsl_state),
         {:ok, dsl_state} <- maybe_build_script(dsl_state) do
      transform_template(dsl_state)
    end
  end

  defp transform_template(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)

    Module.make_overridable(module, [{:render, 0}])

    document = Module.get_attribute(module, :compiled_template)
    template = TemplateTransformer.transform_template(dsl_state, document)

    dsl_state =
      dsl_state
      |> Transformer.eval(
        [],
        quote generated: true, context: module do
          def render do
            unquote(Macros.escape(template))
          end
        end
      )

    {:ok, dsl_state}
  end

  defp build_script_class_name(dsl_state) do
    class_name =
      dsl_state
      |> Transformer.get_persisted(:module)
      |> Module.split()
      |> Enum.join("$")

    {:ok, Transformer.persist(dsl_state, :script_class_name, class_name)}
  end

  defp maybe_build_script(dsl_state) do
    class_name =
      dsl_state
      |> Transformer.get_persisted(:script_class_name)

    {:ok,
     dsl_state
     |> maybe_build_script(:javascript, class_name)
     |> maybe_build_script(:typescript, class_name)}
  end

  defp maybe_build_script(dsl_state, language, class_name) do
    events =
      dsl_state
      |> Transformer.get_entities([:component])
      |> Enum.filter(&is_struct(&1, Event))

    if Enum.any?(events, &(&1.script.lang == language)) do
      script = %Script{
        lang: language,
        # sobelow_skip ["DOS.StringToAtom"]
        script:
          apply(__MODULE__, :"#{language}_generator", [[events: events, class_name: class_name]])
      }

      Transformer.persist(dsl_state, :script, script)
    else
      dsl_state
    end
  end

  defp validate_event_scripts(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:component])
    |> Stream.filter(&is_struct(&1, Event))
    |> Stream.map(&Map.get(&1, :script, %{}))
    |> Stream.map(&Map.get(&1, :lang))
    |> Stream.reject(&is_nil/1)
    |> Enum.uniq()
    |> case do
      [] ->
        :ok

      [_] ->
        :ok

      _ ->
        {:error,
         DslError.exception(
           path: [:component, :event, :script],
           message: "Cannot combine TypeScript and JavaScript scripts in the same component"
         )}
    end
  end

  defp build_slot_schema(dsl_state) do
    slot_schema =
      dsl_state
      |> Transformer.get_entities([:component])
      |> Stream.filter(&is_struct(&1, Slot))
      |> Enum.map(fn slot ->
        {slot.name, [type: {:protocol, Cinder.Template.Render}, required: slot.required?]}
      end)
      |> Keyword.put_new(:default, type: {:protocol, Cinder.Template.Render}, required: false)
      |> PropType.sanitise_schema()

    {:ok, Transformer.persist(dsl_state, :slot_schema, slot_schema)}
  end

  defp build_property_schema(dsl_state) do
    property_schema =
      dsl_state
      |> Transformer.get_entities([:component])
      |> Stream.filter(&is_struct(&1, Property))
      |> Enum.map(fn prop ->
        type =
          if prop.allow_nil? do
            {:option, prop.type}
          else
            prop.type
          end

        {prop.name, [type: type, required: prop.required?, default: prop.default]}
      end)
      |> Keyword.put_new(:request,
        type: {:struct, Request},
        required: false
      )
      |> PropType.sanitise_schema()

    {:ok, Transformer.persist(dsl_state, :property_schema, property_schema)}
  end
end
