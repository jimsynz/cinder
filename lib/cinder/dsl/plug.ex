defmodule Cinder.Dsl.Plug do
  @moduledoc """
  The Plug DSL entity
  """
  defstruct name: nil, options: []

  @type t :: %Cinder.Dsl.Plug{name: module, options: keyword}
end
