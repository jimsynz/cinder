defmodule Cinder.Component.Dsl.Transformer do
  @moduledoc false

  alias Cinder.Request
  alias Spark.{Dsl, Dsl.Transformer}
  use Transformer

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
    template =
      dsl_state
      |> Transformer.get_persisted(:file)
      |> String.replace(~r/\.exs?$/, ".hbs")

    property_schema =
      dsl_state
      |> Transformer.get_entities([:properties])
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

    slot_schema =
      dsl_state
      |> Transformer.get_entities([:slots])
      |> Enum.map(fn slot ->
        {slot.name, [type: {:protocol, Cinder.Template.Render}, required: slot.required?]}
      end)
      |> Keyword.put_new(:default, type: {:protocol, Cinder.Template.Render}, required: false)

    dsl_state =
      dsl_state
      |> Transformer.persist(:property_schema, property_schema)
      |> Transformer.persist(:slot_schema, slot_schema)
      |> Transformer.eval(
        [],
        quote do
          @behaviour Cinder.Component
          import Cinder.Template.Assigns, only: :macros
          import Cinder.Template.Helpers.Block
          import Cinder.Template.Helpers.Expression
          import Cinder.Template.Helpers.Route
          import Cinder.Template.Macros
        end
      )

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
