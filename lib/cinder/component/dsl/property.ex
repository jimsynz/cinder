defmodule Cinder.Component.Dsl.Property do
  @moduledoc """
  The target of the `prop` DSL entity.
  """

  defstruct name: nil, type: :any, required?: true, allow_nil?: false

  @type t :: %__MODULE__{
          name: atom,
          type: Spark.OptionsHelpers.type(),
          required?: boolean,
          allow_nil?: boolean
        }
end