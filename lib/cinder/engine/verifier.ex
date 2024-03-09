defmodule Cinder.Engine.Verifier do
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
      engine = Info.app_engine_module(dsl_state)
      layout = Info.app_layout_module(dsl_state)

      with :ok <- assert_cinder_behaviour(app, engine, Cinder.Engine) do
        assert_cinder_behaviour(app, layout, Cinder.Layout)
      end
    end
  end
end
