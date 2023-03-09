defmodule Cinder.Route.StaticSegment do
  defstruct segment: nil
  alias __MODULE__

  @moduledoc """
  Matches a segment with a static value.

  ## Example

      iex> "posts" |> StaticSegment.init() |> Segment.match("posts")
      {:ok, %{}}
  """

  @type t :: %StaticSegment{segment: String.t()}

  @doc """
  Initialise a new static segment.
  """
  @spec init(String.t()) :: t
  def init(segment), do: %StaticSegment{segment: segment}

  defimpl Cinder.Route.Segment do
    @doc false
    @spec match(StaticSegment.t(), String.t()) ::
            {:ok, %{required(String.t()) => String.t()}} | :error
    def match(%StaticSegment{segment: segment}, input) when segment == input, do: {:ok, %{}}
    def match(_, _), do: :error

    @doc false
    @spec render(StaticSegment.t(), %{required(String.t()) => String.Chars.t()}) ::
            String.t() | no_return
    def render(%StaticSegment{segment: segment}, _), do: segment
  end
end
