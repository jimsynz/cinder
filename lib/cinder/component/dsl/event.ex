defmodule Cinder.Component.Dsl.Event do
  @moduledoc """
  The target of the `event` DSL entity.
  """

  defstruct [:name, :script]

  alias Cinder.Component.{Dsl.Event, Script}

  @type t :: %Event{
          name: atom,
          script: Script.t()
        }
end
