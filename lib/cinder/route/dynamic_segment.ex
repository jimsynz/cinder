defmodule Cinder.Route.DynamicSegment do
  defstruct name: nil
  alias Cinder.Route.DynamicSegment

  @moduledoc """
  Matches a segment with dynamic content.

  ## Example

      iex> "id" |> DynamicSegment.init() |> Segment.match("123")
      {:ok, %{"id" => "123"}}
  """

  @type t :: %DynamicSegment{name: String.t()}

  @doc """
  Initialise a new dynamic segment.
  """
  @spec init(String.t()) :: t
  def init(name), do: %DynamicSegment{name: name}

  defimpl Cinder.Route.Segment do
    @doc false
    @spec match(DynamicSegment.t(), String.t()) ::
            {:ok, %{required(String.t()) => String.t()}} | :error
    def match(%{name: name}, input) when byte_size(input) > 0, do: {:ok, %{name => input}}
    def match(_, _), do: :error

    @doc false
    @spec render(DynamicSegment.t(), %{required(String.t()) => String.Chars.t()}) ::
            String.t() | no_return
    def render(segment, params) do
      params
      |> Map.fetch!(segment.name)
      |> to_string()
    end
  end
end
