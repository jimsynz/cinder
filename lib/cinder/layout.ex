defmodule Cinder.Layout do
  @moduledoc """
  Responsible for rendering the layout around your app's content.
  """

  alias Cinder.Template.Render
  alias Spark.Dsl.Extension

  @callback template :: Render.t()
  @callback __cinder_is__ :: {Cinder.Layout, module}

  @doc false
  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :app)

    app_layout =
      app
      |> Extension.get_persisted(:cinder_template_base_path)
      |> Path.join("layout.hbs")

    default_layout =
      :cinder
      |> :code.priv_dir()
      |> Path.join("templates/default_layout.hbs")

    template =
      if File.exists?(app_layout),
        do: app_layout,
        else: default_layout

    quote location: :keep do
      @behaviour Cinder.Layout
      use Cinder.Template

      @external_resource unquote(app_layout)
      @template_hash Cinder.Template.hash(unquote(app_layout))

      @impl true
      @spec template :: Render.t()
      def template do
        compile_file(unquote(template))
      end

      @impl true
      @spec __cinder_is__ :: {Cinder.Layout, module}
      def __cinder_is__, do: {Cinder.Layout, unquote(app)}

      @doc false
      @spec __mix_recompile__? :: boolean
      def __mix_recompile__? do
        @template_hash != Cinder.Template.hash(unquote(app_layout))
      end

      defoverridable template: 0
    end
  end
end
