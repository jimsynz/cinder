# credo:disable-for-this-file Credo.Check.Refactor.Apply
defmodule Cinder.Route.Transformer do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Cinder.{Dsl.Info, Dsl.Route, Route.DynamicSegment, Route.StaticSegment}
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
    app = Transformer.get_persisted(dsl_state, :module)

    dsl_state = rewrite_routes(dsl_state)

    cinder_route_map = build_route_map(dsl_state)
    cinder_route_modules = Map.keys(cinder_route_map)
    cinder_route_short_name_map = build_short_name_route_map(cinder_route_map)
    cinder_routing_table = build_routing_table(dsl_state)

    cinder_template_base_path =
      get_path_option(dsl_state, :cinder_templates_base_path!, :file_relative)

    cinder_assets_source_path =
      get_path_option(dsl_state, :cinder_assets_source_path!, :app_relative)

    cinder_assets_target_path =
      get_path_option(dsl_state, :cinder_assets_target_path!, :app_relative)

    with :ok <- assert_no_duplicate_route_modules(cinder_route_modules) do
      dsl_state =
        dsl_state
        |> Transformer.persist(:cinder_app_route, Map.fetch!(cinder_route_short_name_map, :app))
        |> Transformer.persist(:cinder_routing_table, cinder_routing_table)
        |> Transformer.persist(:cinder_route_map, cinder_route_map)
        |> Transformer.persist(:cinder_route_short_name_map, cinder_route_short_name_map)
        |> Transformer.persist(:cinder_template_base_path, cinder_template_base_path)
        |> Transformer.persist(:cinder_assets_source_path, cinder_assets_source_path)
        |> Transformer.persist(:cinder_assets_target_path, cinder_assets_target_path)
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
    end
  end

  defp rewrite_routes(dsl_state) do
    namespace =
      dsl_state
      |> Transformer.get_persisted(:module)
      |> Module.concat("Route")

    routes =
      dsl_state
      |> Transformer.get_entities([:cinder, :router])
      |> Enum.filter(&is_struct(&1, Route))
      |> then(fn routes ->
        [
          %Route{
            name: "App",
            path: "/",
            children: routes,
            segments: [%StaticSegment{segment: "/"}]
          },
          %Route{
            name: "Error",
            path: nil,
            children: [],
            segments: []
          }
        ]
      end)
      |> Enum.map(&populate_route_defaults(&1, namespace))

    dsl_state
    |> Transformer.get_entities([:cinder, :router])
    |> Stream.filter(&is_struct(&1, Route))
    |> Enum.reduce(dsl_state, fn route, dsl_state ->
      Transformer.remove_entity(dsl_state, [:cinder, :router], &(&1 == route))
    end)
    |> then(
      &Enum.reduce(routes, &1, fn route, dsl_state ->
        Transformer.add_entity(dsl_state, [:cinder, :router], route)
      end)
    )
  end

  defp populate_route_defaults(%Route{} = route, namespace) do
    module =
      if is_atom(route.name) && Code.ensure_loaded?(route.name),
        do: route.name,
        else: Module.concat(namespace, route.name)

    short_name =
      if route.short_name,
        do: route.short_name,
        # sobelow_skip ["DOS.StringToAtom"]
        else: module |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()

    segments =
      if Enum.any?(route.segments) || is_nil(route.path) do
        route.segments
      else
        route.path
        |> Path.split()
        |> Stream.with_index()
        |> Stream.drop_while(&(&1 == {"/", 0}))
        |> Stream.map(&elem(&1, 0))
        |> Enum.map(&build_segment/1)
      end

    %{
      route
      | name: module,
        short_name: short_name,
        children: Enum.map(route.children, &populate_route_defaults(&1, namespace)),
        segments: segments
    }
  end

  defp assert_no_duplicate_route_modules(cinder_route_modules) do
    cinder_route_modules
    |> Enum.frequencies()
    |> Stream.reject(&(elem(&1, 1) == 1))
    |> Enum.map(&elem(&1, 0))
    |> case do
      [] ->
        :ok

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

  defp get_path_option(dsl_state, config_name, relative_to) do
    configured =
      Info
      |> apply(config_name, [dsl_state])
      |> to_string()

    case {configured, relative_to} do
      {"/" <> _rest = absolute, _} ->
        absolute

      {relative, :app_relative} ->
        otp_app = Transformer.get_persisted(dsl_state, :otp_app)
        Application.app_dir(otp_app, relative)

      {relative, :file_relative} ->
        app_path =
          dsl_state
          |> Transformer.get_persisted(:file)
          |> Path.dirname()

        Path.expand(relative, app_path)
    end
  end

  defp build_routing_table(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:cinder, :router])
    |> Stream.filter(&is_struct(&1, Route))
    |> Enum.reject(&(&1.segments == []))
    |> build_route_entries([])
  end

  defp build_route_map(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:cinder, :router])
    |> Enum.filter(&is_struct(&1, Route))
    |> Enum.reduce(%{}, &build_route_map/2)
  end

  defp build_route_map(route, map) do
    route.children
    |> Enum.reduce(map, &build_route_map/2)
    |> Map.put(route.name, route)
  end

  defp build_short_name_route_map(route_map) do
    route_map
    |> Map.values()
    |> Map.new(&{&1.short_name, &1.name})
  end

  defp build_route_entries([], result), do: result

  defp build_route_entries([route | routes], result) do
    children = build_route_entries(route.children, [])
    entry = cinder_routing_table_entry(route, route.segments, children)
    build_route_entries(routes, [entry | result])
  end

  defp build_segment(":" <> param_name) when byte_size(param_name) > 0,
    do: %DynamicSegment{name: param_name}

  defp build_segment(segment), do: %StaticSegment{segment: segment}

  defp cinder_routing_table_entry(route, [segment], children),
    do: {segment, route.name, children}

  defp cinder_routing_table_entry(router, segments, children) do
    [last | rest] = Enum.reverse(segments)

    Enum.reduce(
      rest,
      {last, router.name, children},
      fn segment, previous ->
        {segment, nil, [previous]}
      end
    )
  end
end
