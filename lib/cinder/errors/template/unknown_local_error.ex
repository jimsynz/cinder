defmodule Cinder.Errors.Template.UnknownLocalError do
  @moduledoc """
  The error raised when a template refers to a local variable that is not set.
  """

  defexception ~w[local file line col]a
  alias __MODULE__

  @type t :: %UnknownLocalError{
          __exception__: true,
          local: atom | binary,
          file: nil | binary,
          line: nil | non_neg_integer(),
          col: nil | non_neg_integer()
        }

  @doc false
  @impl true
  @spec exception(keyword) :: t
  def exception(opts) when is_list(opts) do
    opts
    |> Keyword.take(~w[local file line col]a)
    |> then(&struct!(__MODULE__, &1))
  end

  @doc false
  @impl true
  @spec message(t) :: binary
  def message(error) do
    location =
      case {error.file, error.line, error.col} do
        {nil, nil, nil} -> "at unknown location"
        {file, nil, _} -> "in #{file}"
        {file, line, nil} -> "at #{file}:#{line}"
        {file, line, col} -> "at #{file}:#{line}:#{col}"
      end

    "Attempt to access unknown local variable `#{error.local}` #{location}"
  end

  defimpl Plug.Exception do
    @doc false
    @spec actions(UnknownLocalError.t()) :: []
    def actions(_), do: []

    @doc false
    @spec status(UnknownLocalError.t()) :: non_neg_integer()
    def status(_), do: 500
  end
end
