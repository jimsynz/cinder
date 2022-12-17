defmodule Cinder.Template.Transformer do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Cinder.Route
  alias Spark.{Dsl, Dsl.Transformer, Error.DslError}

  @doc false
  @impl true
  @spec after?(module) :: boolean
  def after?(Route.Transformer), do: true
  def after?(_), do: false

  @doc false
  @impl true
  @spec before?(module) :: boolean
  def before?(_), do: false

  @doc false
  @impl true
  @spec transform(Dsl.t()) :: {:ok, Dsl.t()}
  def transform(dsl_state) do
    app = Transformer.get_persisted(dsl_state, :module)
    route_namespace = Module.concat(app, "Route")
    template_namespace = Module.concat(app, "Template")

    template_base_path =
      dsl_state
      |> Transformer.get_option([:templates], :base_path)
      |> case do
        path when is_binary(path) ->
          path

        path when is_struct(path, Path) ->
          path

        nil ->
          dsl_state
          |> Transformer.get_persisted(:file)
          |> Path.join("../templates")
      end
      |> Path.expand()

    templates =
      dsl_state
      |> Transformer.get_persisted(:route_modules)
      |> Stream.flat_map(fn route ->
        base = delete_module_prefix(route, route_namespace)

        ~w[Loading Active Unloading Error]
        |> Stream.map(&add_module_prefix(&1, base))
      end)
      |> Stream.concat(["Application", "Error"])
      |> Enum.map(fn suffix ->
        module = add_module_prefix(suffix, template_namespace)

        template =
          template_base_path
          |> Path.join(Macro.underscore(suffix))
          |> then(&"#{&1}.html.eex")

        {module, template}
      end)

    dsl_state =
      dsl_state
      |> Transformer.persist(:templates, templates)
      |> Transformer.eval(
        [templates: templates, app: app],
        quote location: :keep do
          for {module, template_path} <- unquote(templates) do
            unless Code.ensure_loaded?(module) || Module.open?(module) do
              defmodule module do
                use Cinder.Template, path: template_path, app: unquote(app)
              end
            end
          end
        end
      )

    {:ok, dsl_state}
  end

  defp delete_module_prefix(module, prefix) do
    module = Module.split(module)

    prefix
    |> Module.split()
    |> Enum.reduce(module, fn hd, [hd | rest] -> rest end)
    |> Module.concat()
  end

  defp add_module_prefix(module, prefix) do
    Module.concat(prefix, module)
  end
end
