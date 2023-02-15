defmodule Cinder.Component.PropType.CssClass do
  @moduledoc """
  Validate an input value as a CSS class.

  Currently doesn't do anything except check that it's a string.
  """

  @doc "Validate the CSS class"
  @spec validate(any) :: {:ok, binary} | {:error, binary}
  def validate(value) when is_binary(value), do: {:ok, value}
  def validate(value), do: {:error, "Expected `#{inspect(value)}` to be a CSS class"}
end
