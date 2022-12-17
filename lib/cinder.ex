defmodule Cinder do
  alias Cinder.Dsl
  import Dsl, only: [dsl: 0]

  @moduledoc """
  The Cinder web application server.

  ## DSL Documentation

  ### Index

  #{Spark.Dsl.Extension.doc_index(dsl())}

  ### Docs

  #{Spark.Dsl.Extension.doc(dsl())}
  """

  use Spark.Dsl, default_extensions: [extensions: [Dsl]]

  @type app :: module

  @doc false
  @spec handle_opts(any) :: Macro.t()
  def handle_opts(_opts) do
    quote location: :keep do
      @persist {:file, __ENV__.file}
    end
  end
end
