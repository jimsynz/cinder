defmodule Cinder.Route.Macros do
  @moduledoc false
  alias Cinder.{Route, Template}
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
          active: "#{underscored}/active.hbs",
          base: "#{underscored}.hbs",
          error: "#{underscored}/error.hbs",
          inactive: "#{underscored}/inactive.hbs",
          loading: "#{underscored}/loading.hbs",
          unloading: "#{underscored}/unloading.hbs"
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
      use Cinder.Template

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
      @spec template(Route.route_state() | :bas) :: Template.Render.t()
      for {state, path} <- state_templates do
        def template(unquote(state)) do
          compile_file(unquote(path))
        end
      end

      if File.exists?(base_template) do
        def template(:base) do
          compile_file(unquote(base_template))
        end
      end

      def template(_) do
        ~B"{{yield}}"
      end
    end
  end
end
