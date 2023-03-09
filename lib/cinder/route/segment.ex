defprotocol Cinder.Route.Segment do
  @moduledoc """
  Protocol for interacting with segments.

  Segments are used to match parts of a path in an inbound HTTP request.
  """

  @doc """
  Perform a segment match, returning any captured parameters.
  """
  @spec match(t, String.t()) :: {:ok, %{required(String.t()) => String.t()}} | :error
  def match(segment, input)

  @doc """
  Convert a previously matched segment back into a string.
  """
  @spec render(t, %{required(String.t()) => String.Chars.t()}) :: String.t() | no_return
  def render(segment, params)
end
