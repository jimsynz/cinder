defmodule Cinder.Template.ExpressionHelpers do
  @moduledoc """
  The built-in expression helpers.
  """

  alias Cinder.Template.Assigns

  defmacro has_slot(slot) do
    quote context: __CALLER__.module, generated: true do
      Assigns.has_key?(slots, unquote(slot))
    end
  end
end
