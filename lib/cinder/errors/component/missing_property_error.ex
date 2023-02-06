defmodule Cinder.Errors.Component.MissingPropertyError do
  @moduledoc """
  The error raised when an expected property is missing from a component invocation.
  """

  defexception ~w[component property file line col]a
  alias __MODULE__

  @type t :: %MissingPropertyError{
          __exception__: true,
          component: module,
          property: atom,
          file: nil | binary,
          line: nil | non_neg_integer(),
          col: nil | non_neg_integer()
        }

  @doc false
  @impl true
  @spec exception(keyword) :: t
  def exception(opts) when is_list(opts) do
    opts
    |> Keyword.take(~w[component property file line col]a)
    |> then(&struct!(MissingPropertyError, &1))
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

    "Required property `#{error.property}` missing when calling component `#{inspect(error.component)}` #{location}"
  end

  defimpl Plug.Exception do
    @doc false
    @spec actions(MissingPropertyError.t()) :: []
    def actions(_), do: []

    @doc false
    @spec status(MissingPropertyError.t()) :: non_neg_integer()
    def status(_), do: 500
  end
end
