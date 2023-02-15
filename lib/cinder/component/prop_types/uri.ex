defmodule Cinder.Component.PropType.Uri do
  @moduledoc """
  Validate that the value is a URI.
  """

  @doc "Validate a URI"
  @spec validate(any) :: {:ok, URI.t()} | {:error, binary}
  def validate(uri) when is_struct(uri, URI), do: {:ok, uri}
  def validate(uri) when is_binary(uri), do: URI.new(uri)
  def validate(_uri), do: {:error, "Invalid URI"}
end
