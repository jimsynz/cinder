defmodule Cinder.Helpers do
  @moduledoc false

  @doc "Convert a list of somethings into a sentence"
  @spec to_sentence(Enumerable.t(), keyword) :: String.t()
  def to_sentence(inputs, options \\ []) do
    sep = Keyword.get(options, :sep, ", ")
    last = Keyword.get(options, :last, " or ")
    mapper = Keyword.get(options, :mapper, &Function.identity/1)

    inputs
    |> Enum.map(mapper)
    |> Enum.reverse()
    |> case do
      [item] ->
        to_string(item)

      [head | tail] ->
        tail =
          tail
          |> Enum.reverse()
          |> Enum.join(sep)

        tail <> last <> head
    end
  end
end
