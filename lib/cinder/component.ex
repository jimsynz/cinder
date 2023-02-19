defmodule Cinder.Component do
  alias Cinder.Component.PropType

  alias Cinder.{
    Component.Dsl,
    Errors.Component.PropertyValidationError,
    Errors.Component.SlotValidationError,
    Errors.Component.UnexpectedPropertyError,
    Errors.Component.UnexpectedSlotError,
    Template.Assigns
  }

  alias NimbleOptions.ValidationError
  alias Spark.{Dsl.Extension, OptionsHelpers}

  @moduledoc """
  A Cinder component.

  ## DSL Documentation

  ### Index

  #{Extension.doc_index(Dsl.dsl())}

  ### Docs

  #{Extension.doc(Dsl.dsl())}
  """

  use Spark.Dsl, default_extensions: [extensions: Dsl]

  @callback render :: Cinder.Template.Render.t()

  @doc false
  @spec validate_props(module, Assigns.t()) :: :ok | {:error, Exception.t()}
  def validate_props(component, assigns)
      when is_atom(component) and is_struct(assigns, Assigns) do
    schema =
      component
      |> Extension.get_persisted(:property_schema, [])
      |> PropType.sanitise_schema()

    with expected <- get_expected_assigns(assigns, schema),
         {:ok, _} <- OptionsHelpers.validate(expected, schema),
         extra when map_size(extra) == 0 <- get_extra_assigns(assigns, schema) do
      :ok
    else
      extra when is_map(extra) ->
        {:error,
         UnexpectedPropertyError.exception(
           component: component,
           properties: Map.keys(extra),
           file: to_string(component.__info__(:compile)[:source])
         )}

      {:error, error} when is_struct(error, ValidationError) ->
        type =
          component
          |> Extension.get_entities([:properties])
          |> Enum.find(%{}, &(&1.name == error.key))
          |> Map.get(:type)

        {:error,
         PropertyValidationError.exception(
           component: component,
           property: error.key,
           message: error.message,
           type: type,
           file: to_string(component.__info__(:compile)[:source])
         )}
    end
  end

  @doc false
  @spec validate_slots(module, Assigns.t()) :: :ok | {:error, Exception.t()}
  def validate_slots(component, slots) when is_atom(component) and is_struct(slots, Assigns) do
    schema =
      component
      |> Extension.get_persisted(:slot_schema, [])
      |> PropType.sanitise_schema()

    with expected <- get_expected_assigns(slots, schema),
         {:ok, _} <- OptionsHelpers.validate(expected, schema),
         extra when map_size(extra) == 0 <- get_extra_assigns(slots, schema) do
      :ok
    else
      extra when is_map(extra) ->
        {:error,
         UnexpectedSlotError.exception(
           component: component,
           properties: Map.keys(extra),
           file: to_string(component.__info__(:compile)[:source])
         )}

      {:error, error} when is_struct(error, ValidationError) ->
        type =
          component
          |> Extension.get_entities([:properties])
          |> Enum.find(%{}, &(&1.name == error.key))
          |> Map.get(:type)

        {:error,
         SlotValidationError.exception(
           component: component,
           property: error.key,
           message: error.message,
           type: type,
           file: to_string(component.__info__(:compile)[:source])
         )}
    end
  end

  @doc false
  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    maybe_template = String.replace(__CALLER__.file, ~r/\.exs?$/, ".hbs")

    head =
      quote generated: true do
        @behaviour Cinder.Component
        import Cinder.Component.Script
        use Cinder.Template

        if File.exists?(unquote(maybe_template)) do
          @external_resource unquote(maybe_template)
          @template_hash Cinder.Template.hash(unquote(maybe_template))

          @doc false
          @spec render :: Cinder.Template.Render.t()
          def render do
            compile_file(unquote(maybe_template))
          end

          @doc false
          @spec __mix_recompile__? :: boolean
          def __mix_recompile__? do
            @template_hash != Cinder.Template.hash(unquote(maybe_template))
          end

          defoverridable render: 0
        end
      end

    tail = super(opts)

    [head] ++ [tail]
  end

  defp get_expected_assigns(assigns, schema) do
    schema
    |> Stream.map(&elem(&1, 0))
    |> Enum.reduce([], fn key, props ->
      if Assigns.has_key?(assigns, key) do
        Keyword.put(props, key, assigns[key])
      else
        props
      end
    end)
  end

  defp get_extra_assigns(assigns, schema) do
    schema
    |> Stream.map(&elem(&1, 0))
    |> Stream.map(&to_string/1)
    |> Enum.reject(&String.starts_with?(&1, "data-"))
    |> then(&Map.drop(assigns.data, &1))
  end
end
