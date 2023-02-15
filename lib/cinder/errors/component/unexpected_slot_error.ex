defmodule Cinder.Errors.Component.UnexpectedSlotError do
  @moduledoc """
  The error raised when a passed-in slot is not of the type specified by the component definition.
  """

  defexception ~w[component slots file line col]a
  alias __MODULE__

  @type t :: %UnexpectedSlotError{
          __exception__: true,
          component: module,
          slots: atom,
          file: nil | binary,
          line: nil | non_neg_integer(),
          col: nil | non_neg_integer()
        }

  @impl true
  @spec exception(keyword) :: t
  def exception(opts) when is_list(opts) do
    opts
    |> Keyword.take(~w[component slots file line col]a)
    |> then(&struct!(UnexpectedSlotError, &1))
  end

  @impl true
  @spec message(t) :: binary
  def message(%{slots: [slot]} = error),
    do:
      "Received unknown slot `#{slot}` when calling component `#{inspect(error.component)}` #{location(error)}"

  def message(error),
    do:
      "Received unknown slots #{Enum.map_join(error.slots, ", ", &"`#{&1}`")} when calling component `#{inspect(error.component)}` #{location(error)}"

  defp location(error) do
    case {error.file, error.line, error.col} do
      {nil, nil, nil} -> "at unknown location"
      {file, nil, _} -> "in #{file}"
      {file, line, nil} -> "at #{file}:#{line}"
      {file, line, col} -> "at #{file}:#{line}:#{col}"
    end
  end

  defimpl Plug.Exception do
    @doc false
    @spec actions(UnexpectedSlotError.t()) :: []
    def actions(_), do: []

    @doc false
    @spec status(UnexpectedSlotError.t()) :: non_neg_integer()
    def status(_), do: 500
  end
end
