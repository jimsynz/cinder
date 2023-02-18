defmodule Cinder.Component.Dsl.Verifier do
  @moduledoc false

  alias Cinder.{
    Errors.Component.RootElementError,
    Template.Rendered.Document,
    Template.Rendered.Element,
    Template.Rendered.VoidElement,
    Template.Rendered.Component
  }

  alias Spark.{Dsl, Dsl.Transformer, Dsl.Verifier}

  use Verifier

  defguardp is_element(node)
            when is_struct(node, Element) or is_struct(node, VoidElement) or
                   is_struct(node, Component)

  @doc false
  @spec verify(Dsl.t()) :: :ok | {:error, DslError}
  def verify(dsl_state) do
    module =
      dsl_state
      |> Transformer.get_persisted(:module)

    module.render()
    |> case do
      %Document{children: [node]} when is_element(node) ->
        :ok

      _ ->
        RootElementError.exception(component: module)
    end
  end
end
