defmodule Cinder.Errors.Component.SlotValidationError do
  @moduledoc """
  The error raised when a passed-in slot is not of the type specified by the component definition.
  """

  defexception ~w[component slot type file line col]a
  alias __MODULE__
  alias Cinder.Component.PropType

  @type t :: %SlotValidationError{
          __exception__: true,
          component: module,
          slot: atom,
          type: PropType.type(),
          file: nil | binary,
          line: nil | non_neg_integer(),
          col: nil | non_neg_integer()
        }

  @impl true
  @spec exception(keyword) :: t
  def exception(opts) when is_list(opts) do
    opts
    |> Keyword.take(~w[component slot type file line col]a)
    |> then(&struct!(SlotValidationError, &1))
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

    "Slot `#{error.slot}` did not match type `#{inspect(error.type)}` when calling component `#{inspect(error.component)}` #{location}"
  end

  defimpl Plug.Exception do
    @doc false
    @spec actions(SlotValidationError.t()) :: []
    def actions(_), do: []

    @doc false
    @spec status(SlotValidationError.t()) :: non_neg_integer()
    def status(_), do: 500
  end
end
