defmodule Cinder.Plug.Verifier do
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
      app = Info.app_module(dsl_state)
      plug = Info.app_plug_module(dsl_state)
      assert_cinder_behaviour(app, plug, Cinder.Plug)
    end
  end
end
