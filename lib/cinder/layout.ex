defmodule Cinder.Layout do
  @moduledoc """
  Responsible for rendering the layout around your app's content.
  """

  alias Cinder.Template.Engine
  alias Spark.Dsl.Extension

  @callback render(map) :: String.t()
  @callback __cinder_is__ :: {Cinder.Layout, module}

  @doc false
  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :app)

    app_layout =
      app
      |> Extension.get_persisted(:cinder_template_base_path)
      |> Path.join("layout.html.eex")

    default_layout =
      :cinder
      |> :code.priv_dir()
      |> Path.join("templates/default_layout.html.eex")

    template =
      if File.exists?(app_layout),
        do: app_layout,
        else: default_layout

    quote location: :keep do
      @behaviour Cinder.Layout
      require EEx

      @impl true
      @spec render(map) :: String.t()
      EEx.function_from_file(:def, :render, unquote(template), [:assigns], engine: Engine)

      @impl true
      @spec __cinder_is__ :: {Cinder.Layout, module}
      def __cinder_is__, do: {Cinder.Layout, unquote(app)}
    end
  end
end
