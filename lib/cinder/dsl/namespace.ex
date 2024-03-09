defmodule Cinder.Dsl.Namespace do
  @moduledoc """
  The Namespace DSL entity
  """
  defstruct namespace: nil

  @type t :: %Cinder.Dsl.Namespace{namespace: module}
end
