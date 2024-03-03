defmodule Cinder.Component do
  alias Cinder.{
    Component.Dsl,
    Errors.Component.PropertyValidationError,
    Errors.Component.SlotValidationError,
    Errors.Component.UnexpectedPropertyError,
    Errors.Component.UnexpectedSlotError,
    Template.Assigns,
    Template.SlotStack
  }

  alias NimbleOptions.ValidationError
  alias Spark.{CheatSheet, Dsl.Extension, OptionsHelpers}

  @moduledoc """
  A Cinder component.

  ## DSL Documentation

  ### Index

  #{CheatSheet.doc_index(Dsl.dsl())}

  ### Docs

  #{CheatSheet.doc(Dsl.dsl())}
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
  @spec validate_slots(module, SlotStack.t()) :: :ok | {:error, Exception.t()}
  def validate_slots(component, slots) when is_atom(component) and is_struct(slots, SlotStack) do
    schema =
      component
      |> Extension.get_persisted(:slot_schema, [])

    with expected <- get_expected_slots(slots, schema),
         {:ok, _} <- OptionsHelpers.validate(expected, schema),
         extra when map_size(extra) == 0 <- get_extra_slots(slots, schema) do
      :ok
    else
      extra when is_map(extra) ->
        {:error,
         UnexpectedSlotError.exception(
           component: component,
           slots: Map.keys(extra),
           file: to_string(component.__info__(:compile)[:source])
         )}

      {:error, error} when is_struct(error, ValidationError) ->
        type =
          component
          |> Extension.get_entities([:slots])
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

        @external_resource unquote(maybe_template)
        @template_hash Cinder.Template.hash(unquote(maybe_template))

        if File.exists?(unquote(maybe_template)) do
          @doc false
          @spec render :: Cinder.Template.Render.t()
          def render do
            compile_file(unquote(maybe_template))
          end

          defoverridable render: 0
        end

        @doc false
        @spec __mix_recompile__? :: boolean
        def __mix_recompile__? do
          @template_hash != Cinder.Template.hash(unquote(maybe_template))
        end
      end

    tail = super(opts)

    [head] ++ [tail]
  end

  defp get_expected_assigns(assigns, schema) do
    schema
    |> Stream.map(&elem(&1, 0))
    |> Enum.reduce([], fn key, props when is_atom(key) ->
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

  defp get_expected_slots(slot_stack, schema) do
    schema
    |> Stream.map(&elem(&1, 0))
    |> Enum.reduce([], fn key, slots when is_atom(key) ->
      if SlotStack.has_slot?(slot_stack, key) do
        Keyword.put(slots, key, SlotStack.get(slot_stack, key))
      else
        slots
      end
    end)
  end

  defp get_extra_slots(slot_stack, schema) do
    schema_keys =
      schema
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    slot_stack
    |> SlotStack.current_keys()
    |> MapSet.new()
    |> MapSet.difference(schema_keys)
    |> Enum.reduce(%{}, fn key, slots ->
      Map.put(slots, key, SlotStack.get(slot_stack, key))
    end)
  end
end
