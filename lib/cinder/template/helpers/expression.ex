defmodule Cinder.Template.Helpers.Expression do
  @moduledoc """
  The built-in expression helpers.
  """

  @doc """
  Inspects it's argument.
  """
  @spec debug(any) :: String.t()
  def debug(any) do
    inspect(any)
  end
end
