defmodule Cinder.Dsl.Plug do
  @moduledoc false
  defstruct name: nil, options: []

  @type t :: %Cinder.Dsl.Plug{name: module, options: keyword}
end
