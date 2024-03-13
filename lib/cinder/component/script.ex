defmodule Cinder.Component.Script do
  @moduledoc """
  A fragment of JavaScript (or TypeScript) code.

  Used the component event DSL.

  To add a fragment of JavaScript code use the `~JS` sigil, or for TypeScript use
  the `~TS` sigil.
  """

  defstruct lang: :javascript, script: nil

  alias Cinder.Component.Script

  @type t :: %Script{lang: :javascript | :typescript, script: binary}

  # credo:disable-for-this-file Credo.Check.Readability.FunctionNames

  @doc false
  @spec sigil_JS(binary, atom) :: t
  def sigil_JS(script, _), do: %Script{lang: :javascript, script: script}

  @doc false
  @spec sigil_TS(binary, atom) :: t
  def sigil_TS(script, _), do: %Script{lang: :typescript, script: script}
end
