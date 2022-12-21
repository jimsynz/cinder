defmodule Cinder.Engine.Macros do
  @moduledoc false

  alias Cinder.{Engine, Engine.State}
  alias Spark.Dsl.Extension

  @doc false
  @spec via(module, Engine.request_id()) :: Macro.t()
  defmacro via(app, request_id) do
    quote location: :keep do
      {:via, Registry,
       {Extension.get_persisted(unquote(app), :cinder_engine_registry), unquote(request_id)}}
    end
  end

  @doc false
  @spec is_transitioning(State.t()) :: Macro.t()
  defguard is_transitioning(state) when state.status == :transitioning
end
