defmodule Cinder.Dsl.Route do
  @moduledoc false
  defstruct name: nil, path: "/", children: [], short_name: nil, segments: []

  alias Cinder.Route.Segment

  @type t :: %Cinder.Dsl.Route{
          name: module,
          path: String.t() | Path.t(),
          children: [t],
          short_name: atom,
          segments: [Segment.t()]
        }
end
