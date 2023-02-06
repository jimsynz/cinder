defmodule Cinder.Errors.Template.IndexError do
  @moduledoc """
  The error raised when a handlebars "path" expression is unable to be evaluated
  due to missing data.
  """

  defexception ~w[parent segment file line col]a
  alias __MODULE__

  @type t :: %IndexError{
          __exception__: true,
          parent: any,
          segment: atom | binary | number,
          file: nil | binary,
          line: nil | non_neg_integer(),
          col: nil | non_neg_integer()
        }

  @doc false
  @impl true
  @spec exception(keyword) :: t
  def exception(opts) when is_list(opts) do
    opts
    |> Keyword.take(~w[parent segment file line col]a)
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

    "Attempt to access unknown missing segment `#{inspect(error.segment)}` of `#{inspect(error.parent)}` in path expression #{location}"
  end

  defimpl Plug.Exception do
    @doc false
    @spec actions(IndexError.t()) :: []
    def actions(_), do: []

    @doc false
    @spec status(IndexError.t()) :: non_neg_integer()
    def status(_), do: 500
  end
end
