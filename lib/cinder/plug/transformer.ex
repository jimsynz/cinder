defmodule Cinder.Plug.Transformer do
  @moduledoc """
  Plug transformer...
  """

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
  @spec transform(Dsl.t()) :: {:ok, Dsl.t()} | {:error, DslError.t()}
  # sobelow_skip ["DOS.StringToAtom"]
  def transform(dsl_state) do
    app =
      dsl_state
      |> Transformer.get_persisted(:module)

    plug =
      app
      |> Module.concat("Plug")

    dsl_state =
      dsl_state
      |> Transformer.persist(
        :cinder_request_key,
        app
        |> Module.split()
        |> Enum.map(&Macro.underscore/1)
        |> Enum.concat(["request_id"])
        |> Enum.join("_")
        |> String.to_atom()
      )
      |> Transformer.persist(:cinder_plug, plug)
      |> Transformer.eval(
        [app: app, plug: plug],
        quote location: :keep do
          unless Code.ensure_loaded?(unquote(plug)) || Module.open?(unquote(plug)) do
            defmodule unquote(plug) do
              use Cinder.Plug, app: unquote(app)
            end
          end
        end
      )

    {:ok, dsl_state}
  end
end
