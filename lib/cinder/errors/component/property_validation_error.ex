defmodule Cinder.Errors.Component.PropertyValidationError do
  @moduledoc """
  The error raised when a passed-in property is not of the type specified by the component definition.
  """

  defexception ~w[component property type file line col]a
  alias __MODULE__

  @type t :: %PropertyValidationError{
          __exception__: true,
          component: module,
          property: atom,
          file: nil | binary,
          line: nil | non_neg_integer(),
          col: nil | non_neg_integer()
        }

  @impl true
  @spec exception(keyword) :: t
  def exception(opts) when is_list(opts) do
    opts
    |> Keyword.take(~w[component property type file line col]a)
    |> then(&struct!(PropertyValidationError, &1))
  end

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

    "Property `#{error.property}` did not match type `#{inspect(error.type)}` when calling component `#{inspect(error.component)}` #{location}"
  end

  defimpl Plug.Exception do
    @doc false
    @spec actions(PropertyValidationError.t()) :: []
    def actions(_), do: []

    @doc false
    @spec status(PropertyValidationError.t()) :: non_neg_integer()
    def status(_), do: 500
  end
end
