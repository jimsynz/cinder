defmodule Cinder.Template.Helpers.Expression do
  @moduledoc """
  The built-in expression helpers.
  """

  alias Cinder.{Template.Assigns, Template.Render}

  @doc """
  Has the slot been passed to this template?
  """
  @spec has_slot(Render.t()) :: Macro.t()
  defmacro has_slot(slot) do
    quote context: __CALLER__.module, generated: true do
      Assigns.has_key?(slots, unquote(slot))
    end
  end
end
