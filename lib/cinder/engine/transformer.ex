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
    app =
      dsl_state
      |> Transformer.get_persisted(:module)

    engine =
      app
      |> Module.concat("Engine")

    dsl_state =
      dsl_state
      |> Transformer.persist(:cinder_engine, engine)
      |> Transformer.persist(:cinder_engine_registry, Module.concat(engine, "Registry"))
      |> Transformer.persist(:cinder_engine_supervisor, Module.concat(engine, "Supervisor"))
      |> Transformer.persist(:cinder_engine_pubsub, Module.concat(engine, "PubSub"))
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
        end
      )

    {:ok, dsl_state}
  end
end
