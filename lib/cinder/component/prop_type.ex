defmodule Cinder.Component.PropType do
  @moduledoc """
  Extensions to `NimbleOptions` and `Spark.OptionsHelpers` for validating properties.
  """

  alias __MODULE__
  alias Spark.OptionsHelpers

  @type type :: :css_class | :uri | OptionsHelpers.type()

  @doc "Convert a schema to one which can be used by `NimbleOptions`"
  @spec sanitise_schema(keyword) :: keyword()
  def sanitise_schema(schema) do
    schema
    |> Enum.map(fn {key, opts} ->
      {key, Keyword.update!(opts, :type, &sanitise_type/1)}
    end)
  end

  @doc "Convert a type to one which can be used by `NimbleOptions`"
  @spec sanitise_type(type) :: OptionsHelpers.nimble_types()
  def sanitise_type(:css_class), do: {:custom, PropType.CssClass, :validate, []}
  def sanitise_type(:uri), do: {:custom, PropType.Uri, :validate, []}

  def sanitise_type({:protocol, protocol}),
    do: {:custom, PropType.Protocol, :validate, [protocol]}

  def sanitise_type({:or, types}), do: {:or, Enum.map(types, &sanitise_type/1)}
  def sanitise_type(type), do: type
end
