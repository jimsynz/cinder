defmodule Cinder.Route.Macros do
  @moduledoc false
  alias Cinder.{Route, Template, Template.Engine}
  alias Spark.Dsl.Extension

  @doc false
  @spec deftemplates(Cinder.app()) :: Macro.t()
  defmacro deftemplates(app) do
    app = Macro.expand(app, __CALLER__)

    underscored =
      app
      |> Extension.get_persisted(:cinder_route_namespace)
      |> then(fn namespace ->
        __CALLER__.module
        |> to_string()
        |> String.replace_prefix("#{namespace}.", "")
      end)
      |> Macro.underscore()

    possible_templates =
      app
      |> Extension.get_persisted(:cinder_template_base_path)
      |> then(fn base_path ->
        [
          base: "#{underscored}.html.eex",
          active: "#{underscored}/active.html.eex",
          inactive: "#{underscored}/inactive.html.eex",
          loading: "#{underscored}/loading.html.eex",
          unloading: "#{underscored}/unloading.html.eex"
        ]
        |> Enum.map(fn {state, path} -> {state, Path.join(base_path, path)} end)
      end)

    state_templates =
      possible_templates
      |> Keyword.delete(:base)
      |> Enum.filter(&File.exists?(elem(&1, 1)))

    base_template =
      possible_templates
      |> Keyword.get(:base)

    quote location: :keep,
          generated: true,
          bind_quoted: [
            possible_templates: possible_templates,
            state_templates: state_templates,
            base_template: base_template
          ] do
      for path <- Keyword.values(possible_templates) do
        @external_resource path
      end

      @template_files Keyword.values(possible_templates)
      @template_hashes Enum.map(@template_files, &Template.hash/1)

      @doc false
      @spec __mix_recompile__? :: boolean
      def __mix_recompile__? do
        @template_hashes != Enum.map(@template_files, &Template.hash/1)
      end

      @doc false
      @spec template(Route.route_state()) :: (Route.assigns() -> String.t())
      for {state, path} <- state_templates do
        def template(unquote(state)) do
          ast = EEx.compile_file(unquote(path), engine: Engine, file: unquote(path), line: 1)

          fn assigns ->
            {result, _bindings} = Code.eval_quoted(ast, assigns: assigns)
            result
          end
        end
      end

      def template(_) do
        ast =
          if File.exists?(unquote(base_template)) do
            EEx.compile_file(unquote(base_template),
              engine: Engine,
              file: unquote(base_template),
              line: 1
            )
          else
            EEx.compile_string("<%= yield %>", engine: Engine)
          end

        fn assigns ->
          {result, _bindings} = Code.eval_quoted(ast, assigns: assigns)
          result
        end
      end
    end
  end
end
