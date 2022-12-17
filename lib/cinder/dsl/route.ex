defmodule Cinder.Dsl.Route do
  @moduledoc false
  defstruct name: nil, path: "/", children: []

  @type t :: %Cinder.Dsl.Route{name: module, path: String.t() | Path.t(), children: [t]}
end
