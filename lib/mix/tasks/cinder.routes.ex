defmodule Mix.Tasks.Cinder.Routes do
  @moduledoc """
  Display the routing table for the specified Cinder application.
  """

  @shortdoc "Display the Cinder routing table"

  use Mix.Task
  alias Cinder.Route.Segment

  @impl true
  def run(args) do
    Mix.Task.run("compile", args)
    Mix.Task.reenable("cinder.routes")

    {opts, args, _} =
      args
      |> OptionParser.parse(strict: [app: :string])

    unless args == [] do
      Mix.raise("Unexpected arguments: #{Enum.map_join(args, ", ", &"`#{&1}`")}")
    end

    app = Keyword.get(opts, :app)

    unless app do
      Mix.raise("Required argument `app` is missing")
    end

    app
    |> String.split(~r/\,\s*/)
    |> Enum.each(fn module ->
      module = Module.concat([module])

      assert_is_module!(module)
      assert_is_cinder_app!(module)
      display_routes(module)
    end)
  end

  defp assert_is_module!(module) do
    unless Code.ensure_loaded?(module) do
      Mix.raise("Value `#{inspect(module)}` is not a module.")
    end
  end

  defp assert_is_cinder_app!(module) do
    Cinder = module.spark_is()
  rescue
    _ -> Mix.raise("Module `#{inspect(module)}` is not a Cinder app.")
  end

  defp display_routes(module) do
    routes =
      module.__cinder_routing_table__()
      |> flatten_routes()

    rendered =
      TableRex.quick_render!(
        routes,
        ["Path", "Route module"],
        "Routing table for app `#{inspect(module)}`"
      )

    Mix.shell().info(rendered)
  end

  defp flatten_routes(routes, parents \\ [], result \\ [])

  defp flatten_routes([], _, result), do: result

  defp flatten_routes([{segment, module, children} | routes], parents, result) do
    segment = Segment.segment(segment)
    segments = [segment | parents]

    path =
      segments
      |> Enum.reverse()
      |> Path.join()

    route_module = if is_nil(module), do: "---", else: inspect(module)

    result = Enum.concat(result, [[path, route_module]])

    result = flatten_routes(children, segments, result)
    flatten_routes(routes, parents, result)
  end
end
