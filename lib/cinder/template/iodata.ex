defmodule Cinder.Template.Iodata do
  @moduledoc """
  Tools for dealing with iodata in streams.
  """

  @type t :: Enumerable.t(char() | binary)

  defguardp is_char(i) when is_integer(i) and i >= 0 and i < 0x10FFFF

  @doc """
  Convert an iodata into a stream.

  ## Example

      iex> [?a, "b", "cd"]
      ...> |> stream()
      ...> |> Enum.to_list()
      [?a, "b", "cd"]
  """
  @spec stream(iodata) :: t
  def stream(iodata),
    do:
      Stream.resource(
        fn -> List.wrap(iodata) end,
        &stream_next/1,
        fn _ -> :ok end
      )

  @doc """
  Convert any chars into binaries.

  ## Example

      iex> [?a, "b", "cd"]
      ...> |> stream()
      ...> |> map_to_binaries()
      ...> |> Enum.to_list()
      ["a", "b", "cd"]
  """
  @spec map_to_binaries(t) :: Enumerable.t(binary)
  def map_to_binaries(stream) do
    stream
    |> Stream.map(fn
      i when is_char(i) -> :unicode.characters_to_binary([i])
      b when is_binary(b) -> b
    end)
  end

  @doc """
  Convert any chars into binaries.

  ## Example

      iex> [?a, "b", "cd"]
      ...> |> stream()
      ...> |> map_to_chars()
      ...> |> Enum.to_list()
      [?a, ?b, ?c, ?d]
  """
  @spec map_to_chars(t) :: Enumerable.t(char)
  def map_to_chars(stream) do
    stream
    |> Stream.flat_map(fn
      i when is_char(i) -> [i]
      b when is_binary(b) -> String.to_charlist(b)
    end)
  end

  @doc """
  Convert a stream of iodata into a stream of binaries of `len` size.

  ## Example

      iex> [?a, "b", "cd"]
      ...> |> stream()
      ...> |> map_into_chunks(2)
      ...> |> Enum.to_list()
      ["ab", "cd"]
  """
  @spec map_into_chunks(t, pos_integer()) :: Enumerable.t(binary)
  def map_into_chunks(stream, len) when is_integer(len) and len > 0 do
    stream
    |> Stream.transform(
      <<>>,
      fn
        i, buffer when is_char(i) when byte_size(buffer) < len ->
          {[], buffer <> :unicode.characters_to_binary([i])}

        i, buffer when is_char(i) ->
          split_binary(buffer <> :unicode.characters_to_binary([i]), len)

        b, buffer when is_binary(b) and byte_size(b) + byte_size(buffer) < len ->
          {[], buffer <> b}

        b, buffer when is_binary(b) ->
          split_binary(buffer <> b, len)
      end
    )
  end

  @doc ~S"""
  Remove any leading whitespace from iodata.

  ## Example

      iex> [" \n", ?\r, "\t " , "abc"]
      ...> |> stream()
      ...> |> trim_leading()
      ...> |> Enum.to_list()
      ["abc"]
  """
  @spec trim_leading(t) :: t
  def trim_leading(stream) do
    stream
    |> Stream.transform(false, fn
      i, false when is_char(i) ->
        [i]
        |> :unicode.characters_to_binary()
        |> String.trim_leading()
        |> case do
          <<>> -> {[], false}
          remainder -> {[remainder], true}
        end

      b, false when is_binary(b) ->
        b
        |> String.trim_leading()
        |> case do
          <<>> -> {[], false}
          remainder -> {[remainder], true}
        end

      any, true ->
        {[any], true}
    end)
  end

  @doc ~S"""
  Remove any trailing whitespace from iodata.

  ## Example

      iex> ["ab", "  ", "c", " \n", ?\r, "\t "]
      ...> |> stream()
      ...> |> trim_trailing()
      ...> |> Enum.to_list()
      ["ab", "  ", "c"]
  """
  @spec trim_trailing(t) :: t
  def trim_trailing(stream) do
    stream
    |> Stream.transform([], fn
      i, buffer when is_char(i) ->
        [i]
        |> :unicode.characters_to_binary()
        |> String.trim_trailing()
        |> case do
          <<>> -> {[], [i | buffer]}
          non_ws -> {Enum.reverse([non_ws | buffer]), []}
        end

      <<>>, buffer ->
        {[], buffer}

      b, buffer when is_binary(b) ->
        b
        |> String.trim_trailing()
        |> case do
          ^b ->
            {Enum.reverse([b | buffer]), []}

          <<>> ->
            {[], [b | buffer]}

          non_ws ->
            ws = binary_slice(b, byte_size(non_ws)..-1//1)
            {Enum.reverse([non_ws | buffer]), [ws]}
        end
    end)
  end

  defp stream_next([]), do: {:halt, []}
  defp stream_next([[head | tail0] | tail1]), do: stream_next([head | [tail0 | tail1]])
  defp stream_next([[] | tail]), do: stream_next(tail)
  defp stream_next([head | tail]) when is_char(head), do: {[head], tail}
  defp stream_next([head | tail]) when is_binary(head), do: {[head], tail}

  defp split_binary(binary, len) when byte_size(binary) < len, do: {[], binary}

  defp split_binary(binary, len), do: split_binary(binary, len, [])

  defp split_binary(remainder, len, result) when byte_size(remainder) < len,
    do: {Enum.reverse(result), remainder}

  defp split_binary(binary, len, result) when byte_size(binary) == len,
    do: {Enum.reverse([binary | result]), <<>>}

  defp split_binary(binary, len, result) do
    head = binary_part(binary, 0, len)
    remainder = binary_slice(binary, len..-1//1)
    split_binary(remainder, len, [head | result])
  end
end
