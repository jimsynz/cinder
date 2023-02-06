defmodule Cinder.Component do
  alias Cinder.Component.Dsl

  @moduledoc """
  A Cinder component.

  ## DSL Documentation

  ### Index

  #{Spark.Dsl.Extension.doc_index(Dsl.dsl())}

  ### Docs

  #{Spark.Dsl.Extension.doc(Dsl.dsl())}
  """

  use Spark.Dsl, default_extensions: [extensions: Dsl]

  @callback render :: Cinder.Template.Render.t()

  @doc false
  @spec handle_opts(any) :: Macro.t()
  def handle_opts(_opts) do
    quote location: :keep do
      @behaviour Cinder.Component
      use Cinder.Template
    end
  end
end
