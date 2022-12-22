defmodule Cinder.Template do
  @moduledoc false

  @doc false
  @spec hash(Path.t()) :: binary | nil
  def hash(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> :erlang.md5()
    end
  end
end
