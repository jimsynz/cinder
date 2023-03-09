defmodule Cinder.Component.PropType do
  @moduledoc """
  Extensions to `NimbleOptions` and `Spark.OptionsHelpers` for validating properties.
  """

  alias __MODULE__
  alias Spark.OptionsHelpers

  @typedoc """
  Currently validates the property as a string, but this should probably be
  smarter in the future.
  """
  @type css_class :: :css_class

  @typedoc """
  Validates that the value is a `URI` struct, or a binary that can be converted
  into one.
  """
  @type uri :: :uri

  @typedoc """
  Validate that the value is of a type which implements the provided protocol.
  """
  @type protocol :: {:protocol, module}

  @typedoc """
  Validate that the value is of the inner type or `nil`.
  """
  @type option(inner) :: {:option, inner}

  @type type :: css_class | uri | protocol | option(any) | OptionsHelpers.type()

  @doc "Convert a schema to one which can be used by `Spark.OptionsHelpers`"
  @spec sanitise_schema(keyword) :: keyword()
  def sanitise_schema(schema) do
    schema
    |> Enum.map(fn {key, opts} ->
      {key, Keyword.update!(opts, :type, &sanitise_type/1)}
    end)
  end

  @doc "Convert a type to one which can be used by `Spark.OptionsHelpers`"
  @spec sanitise_type(type) :: OptionsHelpers.nimble_types()
  def sanitise_type(:css_class), do: {:custom, PropType.CssClass, :validate, []}
  def sanitise_type(:uri), do: {:custom, PropType.Uri, :validate, []}

  def sanitise_type({:option, type}),
    do: {:or, [sanitise_type(type), {:in, [nil]}]}

  def sanitise_type({:protocol, protocol}),
    do: {:custom, PropType.Protocol, :validate, [protocol]}

  def sanitise_type({:map, key_type, value_type}),
    do: {:map, sanitise_type(key_type), sanitise_type(value_type)}

  def sanitise_type({:or, types}), do: {:or, Enum.map(types, &sanitise_type/1)}
  def sanitise_type({:list, type}), do: {:list, sanitise_type(type)}
  def sanitise_type({:tuple, types}), do: {:tuple, Enum.map(types, &sanitise_type/1)}
  def sanitise_type(type), do: type
end
