defmodule Mix.Tasks.Cinder.RegisterComponents do
  @moduledoc """
  This mix task generates javascript or typescript files in your assets
  directory for every Cinder component.

  ## Example

      $ mix cinder.register_components --app Example.App

  ## Command line options

    * `--app` or `-a` - the name of the Cinder application to generate for.
  """

  @shortdoc "Generate Cinder component scripts"

  use Mix.Task

  alias Cinder.Dsl.Info
  alias Spark.Dsl.Extension

  @requirements ["app.start"]
  @impl Mix.Task
  def run(args) do
    with {:ok, app_name} <- get_app_name(args),
         {:ok, app} <- verify_module_is_app(app_name),
         {:ok, asset_path} <- get_asset_source_path(app) do
      asset_path = Path.join(asset_path, "js")

      script_files =
        :code.all_available()
        |> Stream.map(&elem(&1, 0))
        |> Stream.map(&to_string/1)
        |> Stream.filter(&String.starts_with?(&1, "Elixir."))
        |> Stream.map(&String.trim_leading(&1, "Elixir."))
        |> Stream.map(&Module.concat([&1]))
        |> Stream.filter(&is_component_with_script?/1)
        |> Enum.map(&write_component(asset_path, &1))

      write_linking_script(asset_path, script_files)

      Mix.shell().info("""
      Generated `cinder_components.js` with #{length(script_files)} components in assets directory.

      Remember to add `import "./cinder_components" to your app.js.
      """)
    else
      {:error, reason} -> Mix.raise(reason)
    end

    :ok
  end

  defp write_linking_script(asset_path, script_files) do
    imports =
      script_files
      |> Enum.map_join("\n", fn {class_name, relative_path} ->
        "import #{class_name} from \"./#{relative_path}\";"
      end)

    exports =
      script_files
      |> Enum.map_join(", ", &elem(&1, 0))

    script = "#{imports}\n\nexport default { #{exports} };\n"
    path = Path.join(asset_path, "cinder_components.js")

    File.write!(path, script)
  end

  defp is_component_with_script?(component) do
    Code.ensure_loaded?(component) && function_exported?(component, :spark_is, 0) &&
      component.spark_is() == Cinder.Component && has_script?(component)
  end

  defp has_script?(component) do
    case Extension.get_persisted(component, :script) do
      nil -> false
      _ -> true
    end
  end

  defp write_component(path, component) do
    script = Extension.get_persisted(component, :script)
    class_name = Extension.get_persisted(component, :script_class_name)

    file_extension =
      case script.lang do
        :javascript -> "js"
        :typescript -> "ts"
      end

    suffix = Path.join(["components", "#{Macro.underscore(component)}.#{file_extension}"])
    path = Path.join([path, suffix])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, script.script)

    {class_name, suffix}
  end

  defp get_app_name(args) do
    args
    |> OptionParser.parse!(strict: [app: :string], aliases: [a: :app])
    |> elem(0)
    |> Keyword.fetch(:app)
    |> case do
      {:ok, app_name} -> {:ok, app_name}
      :error -> {:error, "You must specify a Cinder application with the `--app` option."}
    end
  end

  defp verify_module_is_app(app_name) do
    module = Module.concat([app_name])

    if function_exported?(module, :spark_is, 0) && module.spark_is() == Cinder do
      {:ok, module}
    else
      {:error, "Module `#{inspect(module)}` is not a Cinder application."}
    end
  end

  defp get_asset_source_path(app) do
    case Info.cinder_assets_source_path(app) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "Your Cinder application doesn't have an asset source path configured."}
    end
  end
end
