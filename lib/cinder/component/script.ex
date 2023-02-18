defmodule Cinder.Component.Script do
  @moduledoc """
  A fragment of JavaScript (or TypeScript) code.

  Used the component event DSL.

  To add a fragment of JavaScript code use the `~j` sigil, or for TypeScript use
  the `~t` sigil.
  """

  defstruct lang: :javascript, script: nil

  alias Cinder.Component.Script

  @type t :: %Script{lang: :javascript | :typescript, script: binary}

  @doc false
  @spec sigil_j(binary, atom) :: t
  def sigil_j(script, _), do: %Script{lang: :javascript, script: script}

  @doc false
  @spec sigil_t(binary, atom) :: t
  def sigil_t(script, _), do: %Script{lang: :typescript, script: script}
end
