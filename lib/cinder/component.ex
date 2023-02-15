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
    |> Enum.map(&to_string/1)
    |> then(&Map.drop(assigns.data, &1))
  end
end
