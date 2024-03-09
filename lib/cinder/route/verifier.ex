defmodule Cinder.Route.Verifier do
  @moduledoc false
  use Spark.Dsl.Verifier
  alias Cinder.Dsl.Info
  alias Spark.{Dsl, Error.DslError}
  import Cinder.Helpers

  @doc false
  @impl true
  @spec verify(Dsl.t()) :: :ok | {:error, DslError.t()}
  def verify(dsl_state) do
    if Info.cinder_auto_define_modules?(dsl_state) do
      :ok
    else
      verify_route_modules(dsl_state)
    end
  end

  defp verify_route_modules(dsl_state) do
    app = Info.app_module(dsl_state)

    dsl_state
    |> Info.app_route_modules()
    |> Enum.reduce_while(:ok, fn route, :ok ->
      case assert_cinder_behaviour(app, route, Cinder.Route) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
