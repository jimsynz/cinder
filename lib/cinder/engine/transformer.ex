defmodule Cinder.Engine.Transformer do
  @moduledoc false
  use Spark.Dsl.Transformer
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
  @spec transform(Dsl.t()) :: {:ok, Dsl.t()}
  def transform(dsl_state) do
    app = Transformer.get_persisted(dsl_state, :module)
    engine = Module.concat(app, "Engine")
    layout = Module.concat(app, "Layout")

    with {:ok, dsl_state} <- transform_bind_address(dsl_state) do
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

  defp transform_bind_address(dsl_state) do
    dsl_state
    |> Transformer.get_option([:cinder], :bind_address)
    |> Enum.reduce_while({:ok, []}, fn address, {:ok, addresses} ->
      case IP.Address.from_string(address) do
        {:ok, address} ->
          {:cont, {:ok, [address | addresses]}}

        {:error, _} ->
          {:halt,
           {:error,
            DslError.exception(
              module: Transformer.get_persisted(dsl_state, :module),
              path: [:cinder],
              message: "Bind address `#{inspect(address)}` is not a valid IP address."
            )}}
      end
    end)
    |> case do
      {:ok, addresses} ->
        {:ok,
         Transformer.set_option(dsl_state, [:cinder], :bind_address, Enum.reverse(addresses))}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
