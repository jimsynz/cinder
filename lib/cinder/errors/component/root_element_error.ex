defmodule Cinder.Errors.Component.RootElementError do
  @moduledoc """
  The error raised when a component template contains more than a single root
  node.
  """
  alias Cinder.Errors.Component.RootElementError

  defexception ~w[component file line col]a
  alias __MODULE__

  @type t :: %RootElementError{
          __exception__: true,
          component: module,
          file: nil | binary,
          line: nil | non_neg_integer(),
          col: nil | non_neg_integer()
        }

  @impl true
  @spec exception(keyword) :: t
  def exception(opts) when is_list(opts) do
    opts
    |> Keyword.take(~w[component file line col]a)
    |> then(&struct!(RootElementError, &1))
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

    "Component templates must contain only a single root element #{location}"
  end
end
