defmodule Cinder.Template.Macros do
  alias Cinder.Template.Compiler

  @moduledoc """
  Macros related to templating.
  """

  @doc """
  Compile an inline template into the current module.
  """
  @spec sigil_B({:<<>>, keyword, [binary]}, [atom]) :: Macro.t()
  defmacro sigil_B({:<<>>, meta, [template]}, _) do
    line = Keyword.get(meta, :line, 1)
    column = Keyword.get(meta, :column, 1)
    compiled = Compiler.compile(template, __CALLER__, __CALLER__.file, line, column)

    Module.put_attribute(__CALLER__.module, :compiled_template, compiled)

    quote context: __CALLER__.module, generated: true do
      unquote(__MODULE__.escape(compiled))
    end
  end

  @doc """
  Compile a template file into the current module.
  """
  @spec compile_file(binary) :: Macro.t() | no_return
  defmacro compile_file(path) do
    template =
      path
      |> Macro.expand(__CALLER__)
      |> File.read!()

    compiled = Compiler.compile(template, __CALLER__, path, 1, 1)

    Module.put_attribute(__CALLER__.module, :compiled_template, compiled)

    quote context: __CALLER__.module, generated: true do
      unquote(__MODULE__.escape(compiled))
    end
  end

  @doc """
  A special AST escaper that escapes everything except functions in map values.
  """
  @spec escape(any) :: any
  def escape(%_{} = val) do
    escaped =
      val
      |> Map.to_list()
      |> Enum.map(fn
        {key, {:fn, _, _} = value} ->
          {escape(key), value}

        {key, value} ->
          {escape(key), escape(value)}
      end)

    {:%{}, [], escaped}
  end

  def escape(%{} = val) do
    escaped =
      val
      |> Map.to_list()
      |> Enum.map(fn
        {key, {:fn, _, _} = value} ->
          {escape(key), value}

        {key, value} ->
          {escape(key), escape(value)}
      end)

    {:%{}, [], escaped}
  end

  def escape(other) when is_list(other), do: Enum.map(other, &escape(&1))
  def escape(other), do: Macro.escape(other)
end
