defmodule Cinder.Template.HtmlEscaper do
  @moduledoc """
  Handles the safe escaping of HTML attributes and expressions for
  interpolation.
  """

  @escapes [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  @doc "Escape the iodata for interpolation into HTML"
  @spec escape(any) :: iodata
  def escape(value) when is_binary(value) do
    value
    |> String.to_charlist()
    |> escape([])
  end

  def escape(value) when is_list(value), do: escape(value, [])

  defp escape([], result), do: Enum.reverse(result)

  for {match, replacement} <- @escapes do
    defp escape([unquote(match) | input], result),
      do: escape(input, [unquote(replacement) | result])
  end

  defp escape([iodata | input], result) when is_binary(iodata) or is_list(iodata),
    do: escape(input, [escape(iodata) | result])

  defp escape([chr | input], result) when is_integer(chr) and chr >= 0,
    do: escape(input, [chr | result])

  defp escape([wat | input], result), do: escape(input, [escape(to_string(wat)) | result])
end
