defmodule Cinder.Secret.AnonFn do
  @moduledoc "Implementation of Cinder.Secret for anonymous functions"
  use Cinder.Secret

  @doc false
  @impl true
  @spec secret(atom, keyword) :: {:ok, String.t()} | no_return
  def secret(secret_name, opts) do
    case Keyword.pop(opts, :fun) do
      {fun, _opts} when is_function(fun, 1) ->
        fun.(secret_name)

      {fun, opts} when is_function(fun, 2) ->
        fun.(secret_name, opts)

      {{m, f, a}, _opts} when is_atom(m) and is_atom(f) and is_list(a) ->
        apply(m, f, [secret_name | a])

      {nil, opts} ->
        raise "Invalid options given to `secret/2` callback: `#{inspect(opts)}`."
    end
  end
end
