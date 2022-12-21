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

    cinder_routing_table =
      dsl_state
      |> Transformer.get_entities([:cinder, :router])
      |> Enum.filter(&is_struct(&1, Route))
      |> build_route_entries([], namespace)
      |> then(fn cinder_routing_table ->
        [{%StaticSegment{segment: "/"}, Module.concat(namespace, "App"), cinder_routing_table}]
      end)

    cinder_route_modules =
      cinder_routing_table
      |> Stream.flat_map(&extract_cinder_route_modules/1)
      |> Enum.sort()

    duplicate_modules =
      cinder_route_modules
      |> Enum.frequencies()
      |> Stream.reject(&(elem(&1, 1) == 1))
      |> Enum.map(&elem(&1, 0))

    case duplicate_modules do
      [] ->
        dsl_state =
          dsl_state
          |> Transformer.persist(:cinder_routing_table, cinder_routing_table)
          |> Transformer.persist(:cinder_route_modules, cinder_route_modules)
          |> Transformer.persist(:cinder_app_route, Module.concat(namespace, "App"))
          |> Transformer.eval(
            [
              cinder_route_modules: cinder_route_modules,
              cinder_routing_table: cinder_routing_table,
              app: app
            ],
            quote location: :keep do
              def __cinder_routing_table__, do: unquote(Macro.escape(cinder_routing_table))

              for module <- unquote(cinder_route_modules) do
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
      entry = cinder_routing_table_entry(route, segments, children, namespace)
      build_route_entries(routes, [entry | result], namespace)
    end)
  end

  defp build_segment(":" <> param_name) when byte_size(param_name) > 0,
    do: %DynamicSegment{name: param_name}

  defp build_segment(segment), do: %StaticSegment{segment: segment}

  defp cinder_routing_table_entry(route, [segment], children, namespace),
    do: {segment, Module.concat(namespace, route.name), children}

  defp cinder_routing_table_entry(router, segments, children, namespace) do
    [last | rest] = Enum.reverse(segments)

    Enum.reduce(rest, {last, Module.concat(namespace, router.name), children}, fn segment,
                                                                                  previous ->
      {segment, nil, [previous]}
    end)
  end

  defp extract_cinder_route_modules({_, module, children}) do
    children
    |> Stream.flat_map(&extract_cinder_route_modules/1)
    |> Stream.concat([module])
    |> Stream.reject(&is_nil/1)
  end
end
