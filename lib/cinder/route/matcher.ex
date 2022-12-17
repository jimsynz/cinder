defmodule Cinder.Route.Matcher do
  alias Cinder.{Route, Route.Segment}

  @moduledoc """
  Matches path segments against a given routing table.
  """

  @doc """
  Match a list of path segments against a routing table.

  ## Example

      iex> "/posts/123/comments" |> Path.split() |> Matcher.match(Example.App.__routing_table__())
      {:ok, [{%{}, Example.App.Route.App}, {%{}, Example.App.Route.Posts}, {%{"id" => "123"}, Example.App.Route.Post}, {%{}, Example.App.Route.Comments}]}

      iex> "/fruits/banana" |> Path.split() |> Matcher.match(Example.App.__routing_table__())
      {:ok, [{%{}, Example.App.Route.App}, {%{}, nil}, {%{"id" => "banana"}, Example.App.Route.Fruit}]}

  """
  @spec match([String.t()], Route.routing_table()) ::
          {:ok, [{%{required(String.t()) => String.t()}, Route.route_module()}]} | :error
  def match(segments, routes), do: match(segments, routes, [])

  defp match([], _routes, _result), do: :error

  defp match([segment], routes, result) do
    case match_segment(segment, routes) do
      {:ok, {params, route, _children}} -> {:ok, [{params, route} | result]}
      :error -> :error
    end
  end

  defp match([segment | remaining], routes, result) do
    with {:ok, {params, route, children}} <- match_segment(segment, routes),
         {:ok, result} <- match(remaining, children, result) do
      {:ok, [{params, route} | result]}
    end
  end

  defp match_segment(segment, routes) do
    find_result_value(routes, fn {matcher, route, children} ->
      case Segment.match(matcher, segment) do
        {:ok, params} -> {:ok, {params, route, children}}
        :error -> :error
      end
    end)
  end

  defp find_result_value(collection, fun) when is_function(fun, 1) do
    Enum.reduce_while(collection, :error, fn element, _ ->
      case fun.(element) do
        {:ok, value} -> {:halt, {:ok, value}}
        :error -> {:cont, :error}
      end
    end)
  end
end
