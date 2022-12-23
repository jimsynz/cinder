defmodule Cinder.Engine.Transformer do
  @moduledoc false
  use Spark.Dsl.Transformer
  alias Spark.{Dsl, Dsl.Transformer}

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
  @spec transform(Dsl.t()) :: {:ok, Dsl.t()}
  def transform(dsl_state) do
    app = Transformer.get_persisted(dsl_state, :module)
    engine = Module.concat(app, "Engine")
    layout = Module.concat(app, "Layout")

    dsl_state =
      dsl_state
      |> Transformer.persist(:cinder_engine, engine)
      |> Transformer.persist(:cinder_engine_registry, Module.concat(engine, "Registry"))
      |> Transformer.persist(:cinder_engine_supervisor, Module.concat(engine, "Supervisor"))
      |> Transformer.persist(:cinder_pubsub, Module.concat(engine, "PubSub"))
      |> Transformer.persist(:cinder_layout, layout)
      |> Transformer.eval(
        [app: app, engine: engine],
        quote location: :keep do
          @doc false
          @spec child_spec(keyword) :: Supervisor.child_spec()
          def child_spec(opts) do
            %{
              id: unquote(app),
              start: {unquote(engine), :start_link, [[]]}
            }
          end

          unless Code.ensure_loaded?(unquote(engine)) || Module.open?(unquote(engine)) do
            defmodule unquote(engine) do
              use Cinder.Engine, app: unquote(app)
            end
          end

          unless Code.ensure_loaded?(unquote(layout)) || Module.open?(unquote(layout)) do
            defmodule unquote(layout) do
              use Cinder.Layout, app: unquote(app)
            end
          end
        end
      )

    {:ok, dsl_state}
  end
end
