defmodule Cinder.Component.Dsl.Transformer do
  @moduledoc false

  alias Spark.{Dsl, Dsl.Transformer}
  use Transformer

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
    {:ok, dsl_state}
  end
end
