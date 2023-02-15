defmodule Cinder.Component.Dsl.Slot do
  @moduledoc """
  The target of the `slot` DSL entity.
  """

  defstruct name: nil, required?: true, trim?: false

  @type t :: %__MODULE__{
          name: atom,
          required?: boolean,
          trim?: boolean
        }
end
