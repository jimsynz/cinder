defmodule Cinder.Template.Helpers.Route do
  @moduledoc """
  Template helpers for interacting with routes.
  """

  alias Cinder.{Dsl.Info, Request, Route.DynamicSegment, Route.StaticSegment}

  @doc """
  Serialises the current route into a string.
  """
  @spec current_route(Request.t()) :: binary
  def current_route(request) when is_struct(request, Request) do
    request
    |> Map.get(:current_routes, [])
    |> Enum.map_join(".", fn route ->
      name = route_short_name(route.module, request.app)

      route.params
      |> Enum.map_join(",", fn {key, value} -> "#{key}=#{value}" end)
      |> case do
        "" -> name
        params -> "#{name}[#{params}]"
      end
    end)
  end

  @doc """
  Convert a route string into a path.
  """
  @spec url_for(Request.t(), binary, keyword) :: URI.t()
  def url_for(request, route, params \\ []) do
    params =
      params
      |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)

    {segments, extra_params} =
      route
      |> String.split(".")
      |> Stream.map(&String.split(&1, ~r/[\[\]]/))
      |> Enum.reduce({[], params}, fn
        [segment], {result, params} ->
          {[{segment, %{}} | result], params}

        [segment, param, _], {result, params} ->
          case pop_first(params, param) do
            {nil, _params} -> raise "Missing value for param `#{param}`"
            {value, params} -> {[{segment, %{param => value}} | result], params}
          end
      end)

    if Enum.any?(extra_params) do
      names = Enum.map_join(extra_params, ", ", &"`#{elem(&1, 0)}`")
      raise "Found extra unused parameters: #{names}"
    end

    segments = Enum.reverse(segments)
    routing_table = request.app.__cinder_routing_table__()
    target = build_uri_from_routing_table_and_segments(segments, routing_table, [], request.app)

    URI.new!(target)
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

  defp build_uri_from_routing_table_and_segments([], _routing_table, result, _app),
    do: result |> Enum.reverse() |> Path.join()

  defp build_uri_from_routing_table_and_segments(
         [{segment_name, _} | _segments],
         [],
         _result,
         _app
       ),
       do: raise("Unable to build URI for segment `#{segment_name}`.")

  defp build_uri_from_routing_table_and_segments(
         [{segment_name, params} | segments],
         routing_table,
         result,
         app
       ) do
    route =
      routing_table
      |> Stream.map(fn {segment, module, params} ->
        {segment, module, params, route_short_name(module, app)}
      end)
      |> Enum.find_value(fn
        {segment, _, params, short_name} when short_name == segment_name ->
          {segment, params}

        {segment, nil, params, _}
        when is_struct(segment, Static) and segment.segment == segment_name ->
          {segment, params}

        _ ->
          nil
      end)

    case {route, params} do
      {{segment, children}, params}
      when is_struct(segment, StaticSegment) and map_size(params) == 0 ->
        build_uri_from_routing_table_and_segments(
          segments,
          children,
          [segment.segment | result],
          app
        )

      {{segment, children}, params}
      when is_struct(segment, DynamicSegment) and is_map_key(params, segment.name) ->
        build_uri_from_routing_table_and_segments(
          segments,
          children,
          [Map.fetch!(params, segment.name) | result],
          app
        )

      _ ->
        raise("Unable to build URI for segment `#{segment_name}`.")
    end
  end

  defp route_short_name(nil, _app), do: nil

  defp route_short_name(route, app) do
    namespace = Info.cinder_route_namespace(app)
    to_remove = Module.split(namespace)
    segments = Module.split(route)
    dropped = Enum.take(segments, length(to_remove))

    unless dropped == to_remove do
      raise "Unable to remove route namespace `#{inspect(namespace)}` from `#{inspect(route)}`"
    end

    segments
    |> Enum.drop(length(to_remove))
    |> Module.concat()
    |> Macro.underscore()
  end
end
