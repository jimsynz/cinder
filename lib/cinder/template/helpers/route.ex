defmodule Cinder.Template.Helpers.Route do
  @moduledoc """
  Template helpers for interacting with routes.
  """

  alias Cinder.{Dsl.Info, Request, Route.DynamicSegment, Route.Segment, Route.StaticSegment}

  @doc """
  Serialises the current route into a string.
  """
  @spec current_route(Request.t()) :: URI.t()
  def current_route(request) when is_struct(request, Request) do
    request.current_routes
    |> Enum.flat_map(fn route ->
      {:ok, dsl_route} = Info.fetch_route_by_module(request.app, route.module)

      dsl_route.segments
      |> Stream.map(&Segment.render(&1, route.params))
    end)
    |> Path.join()
    |> URI.new!()
  end

  @doc """
  Returns the "route identifier" for the current route.
  """
  @spec current_route_id(Request.t()) :: String.t()
  def current_route_id(request) when is_struct(request, Request) do
    request.current_routes
    |> Enum.flat_map(fn route ->
      {:ok, dsl_route} = Info.fetch_route_by_module(request.app, route.module)

      dsl_route.segments
      |> Stream.map(&Segment.segment/1)
    end)
    |> Path.join()
  end

  @doc """
  Convert a route string into a path.
  """
  @spec url_for(Request.t(), URI.t() | binary, keyword) :: URI.t()
  def url_for(request, path, params \\ [])

  def url_for(request, uri, params) when is_struct(uri, URI),
    do: url_for(request, uri.path, params)

  def url_for(request, path, params) when is_binary(path) do
    routing_table = request.app.__cinder_routing_table__()

    path
    |> Path.split()
    |> validate_segments(routing_table, params, [])
    |> Path.join()
    |> URI.new!()
  end

  defp validate_segments([], _routes, _params, result), do: Enum.reverse(result)

  defp validate_segments([head | tail], routes, params, result) do
    routes
    |> Enum.find(fn
      {%StaticSegment{segment: ^head}, _, _} -> true
      {%DynamicSegment{name: name}, _, _} -> ":#{name}" == head
      _ -> false
    end)
    |> case do
      nil ->
        raise "Route segment `#{head}` does not match any route"

      {%StaticSegment{segment: segment}, _, children} ->
        validate_segments(tail, children, params, [segment | result])

      {%DynamicSegment{name: name}, _, children} ->
        case pop_first(params, name) do
          {nil, _params} ->
            raise "Missing parameter `#{name}`."

          {value, params} ->
            validate_segments(tail, children, params, [to_string(value) | result])
        end
    end
  end

  defp pop_first(params, string_key, searched \\ [])

  defp pop_first([], _string_key, searched), do: {nil, searched}

  defp pop_first([{atom_key, value} | params], string_key, searched) do
    if to_string(atom_key) == string_key do
      {value, params ++ Enum.reverse(searched)}
    else
      pop_first(params, string_key, [{atom_key, value} | searched])
    end
  end
end
