defmodule Cinder.Component.Dsl.Transformer do
  @moduledoc false

  alias Cinder.Request
  alias Cinder.Component.{Dsl.Event, Dsl.Property, Dsl.Slot, Script}
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
         {:ok, dsl_state} <- maybe_compile_template(dsl_state),
         {:ok, dsl_state} <- build_property_schema(dsl_state),
         {:ok, dsl_state} <- build_slot_schema(dsl_state),
         {:ok, dsl_state} <- add_eval(dsl_state) do
      maybe_build_script(dsl_state)
    end
  end

  defp maybe_build_script(dsl_state) do
    {:ok,
     dsl_state
     |> maybe_build_script(:javascript)
     |> maybe_build_script(:typescript)}
  end

  defp maybe_build_script(dsl_state, language) do
    events =
      dsl_state
      |> Transformer.get_entities([:component])
      |> Enum.filter(&is_struct(&1, Event))

    if Enum.any?(events, &(&1.script.lang == language)) do
      class_name =
        dsl_state
        |> Transformer.get_persisted(:module)
        |> Module.split()
        |> Enum.join("$")

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

  defp add_eval(dsl_state) do
    {:ok,
     Transformer.eval(
       dsl_state,
       [],
       quote do
         @behaviour Cinder.Component
         import Cinder.Template.Assigns, only: :macros
         import Cinder.Template.Helpers.Block
         import Cinder.Template.Helpers.Expression
         import Cinder.Template.Helpers.Route
         import Cinder.Template.Macros
       end
     )}
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

    {:ok, Transformer.persist(dsl_state, :slot_schema, slot_schema)}
  end

  defp build_property_schema(dsl_state) do
    property_schema =
      dsl_state
      |> Transformer.get_entities([:component])
      |> Stream.filter(&is_struct(&1, Property))
      |> Enum.map(fn
        prop when prop.allow_nil? == true ->
          {prop.name, [type: {:or, [prop.type, {:in, [nil]}]}, required: prop.required?]}

        prop ->
          {prop.name, [type: prop.type, required: prop.required?]}
      end)
      |> Keyword.put_new(:request,
        type: {:struct, Request},
        required: false
      )

    {:ok, Transformer.persist(dsl_state, :property_schema, property_schema)}
  end

  defp maybe_compile_template(dsl_state) do
    template =
      dsl_state
      |> Transformer.get_persisted(:file)
      |> String.replace(~r/\.exs?$/, ".hbs")

    dsl_state =
      if File.exists?(template) do
        dsl_state
        |> Transformer.eval(
          [],
          quote do
            @external_resource unquote(template)
            @template_hash Cinder.Template.hash(unquote(template))

            @doc false
            @spec render :: Cinder.Template.Render.t()
            def render do
              compile_file(unquote(template))
            end

            @doc false
            @spec __mix_recompile__? :: boolean
            def __mix_recompile__? do
              @template_hash != Cinder.Template.hash(unquote(template))
            end

            defoverridable render: 0
          end
        )
      else
        dsl_state
      end

    {:ok, dsl_state}
  end
end
