defmodule Cinder.Component.Dsl.Property do
  @moduledoc """
  The target of the `prop` DSL entity.
  """

  defstruct name: nil, type: :any, required?: true

  @type t :: %__MODULE__{
          name: atom,
          type: Spark.OptionsHelpers.type(),
          required?: boolean
        }
end
