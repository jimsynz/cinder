defmodule Cinder.Dsl.Namespace do
  @moduledoc false
  defstruct namespace: nil

  @type t :: %Cinder.Dsl.Namespace{namespace: module}
end
