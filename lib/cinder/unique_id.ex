defmodule Cinder.UniqueId do
  @moduledoc "Generates unique string identifiers."

  @type unique_id :: String.t()

  @doc "Generate a unique string identifier of specified length"
  @spec unique_id(pos_integer) :: unique_id()
  def unique_id(length \\ 16) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
  end
end
