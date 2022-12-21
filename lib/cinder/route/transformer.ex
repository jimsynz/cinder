defmodule Cinder.Route.Transformer do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Cinder.{Dsl.Route, Route.DynamicSegment, Route.StaticSegment}
  alias Spark.{Dsl, Dsl.Transformer, Error.DslError}

  @doc false
  @impl true
  @spec after?(module) :: boolean
  def after?(_), do: false

  @doc false
  @impl true
  @spec before?(module) :: boolean
  def before?(_), do: false

  @doc false
  @impl true
  @spec transform(Dsl.t()) :: {:ok, Dsl.t()} | {:error, DslError.t()}
  def transform(dsl_state) do
    app =
      dsl_state
      |> Transformer.get_persisted(:module)

    namespace =
      app
      |> Module.concat("Route")

    routing_table =
      dsl_state
      |> Transformer.get_entities([:cinder, :router])
      |> Enum.filter(&is_struct(&1, Route))
      |> build_route_entries([], namespace)
      |> then(fn routing_table ->
        [{%StaticSegment{segment: "/"}, Module.concat(namespace, "App"), routing_table}]
      end)

    route_modules =
      routing_table
      |> Stream.flat_map(&extract_route_modules/1)
      |> Enum.sort()

    duplicate_modules =
      route_modules
      |> Enum.frequencies()
      |> Stream.reject(&(elem(&1, 1) == 1))
      |> Enum.map(&elem(&1, 0))

    case duplicate_modules do
      [] ->
        dsl_state =
          dsl_state
          |> Transformer.persist(:routing_table, routing_table)
          |> Transformer.persist(:route_modules, route_modules)
          |> Transformer.eval(
            [route_modules: route_modules, routing_table: routing_table, app: app],
            quote location: :keep do
              def __routing_table__, do: unquote(Macro.escape(routing_table))

              for module <- unquote(route_modules) do
                unless Code.ensure_loaded?(module) || Module.open?(module) do
                  defmodule module do
                    use Cinder.Route, app: unquote(app)
                  end
                end
              end
            end
          )

        {:ok, dsl_state}

      [module] ->
        {:error,
         DslError.exception(
           path: [:router, :route],
           message:
             "Routes must have unique names, but `#{inspect(module)}` occurs more than once"
         )}

      modules ->
        modules = Enum.map_join(modules, ",", &"`#{inspect(&1)}`")

        {:error,
         DslError.exception(
           path: [:router, :route],
           message:
             "Route modules must have unique names, but the following modules occur more than once: #{modules}"
         )}
    end
  end

  defp build_route_entries([], result, _namespace), do: result

  defp build_route_entries([route | routes], result, namespace) do
    route.path
    |> Path.split()
    |> Stream.with_index()
    |> Stream.drop_while(&(&1 == {"/", 0}))
    |> Stream.map(&elem(&1, 0))
    |> Enum.map(&build_segment/1)
    |> then(fn segments ->
      children = build_route_entries(route.children, [], namespace)
      entry = routing_table_entry(route, segments, children, namespace)
      build_route_entries(routes, [entry | result], namespace)
    end)
  end

  defp build_segment(":" <> param_name) when byte_size(param_name) > 0,
    do: %DynamicSegment{name: param_name}

  defp build_segment(segment), do: %StaticSegment{segment: segment}

  defp routing_table_entry(route, [segment], children, namespace),
    do: {segment, Module.concat(namespace, route.name), children}

  defp routing_table_entry(router, segments, children, namespace) do
    [last | rest] = Enum.reverse(segments)

    Enum.reduce(rest, {last, Module.concat(namespace, router.name), children}, fn segment,
                                                                                  previous ->
      {segment, nil, [previous]}
    end)
  end

  defp extract_route_modules({_, module, children}) do
    children
    |> Stream.flat_map(&extract_route_modules/1)
    |> Stream.concat([module])
    |> Stream.reject(&is_nil/1)
  end
end
