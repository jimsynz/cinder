defmodule Cinder.Template.Compiler do
  @moduledoc """
  The template compiler.
  """

  alias Cinder.Errors.{
    Template.IndexError,
    Template.UnknownAssignError,
    Template.UnknownLocalError
  }

  alias Cinder.Template.{
    Assigns,
    Compilable,
    Render,
    Rendered.Attribute,
    Rendered.Block,
    Rendered.Component,
    Rendered.Document,
    Rendered.Element,
    Rendered.Expression,
    Rendered.RawExpression,
    Rendered.Static,
    Rendered.VoidElement
  }

  defguardp is_element(node) when is_struct(node, Element) or is_struct(node, VoidElement)

  @doc """
  Compile the template into data structure (with quoted functions ready for unquoting).
  """
  @spec compile(binary, Macro.Env.t(), binary, non_neg_integer(), non_neg_integer()) :: Render.t()
  def compile(template, env, file \\ "nofile", line \\ 1, column \\ 1) do
    args =
      env
      |> Macro.Env.vars()
      |> Enum.map(fn {arg_name, _} ->
        {arg_name,
         quote context: env.module do
           var!(unquote({arg_name, [], env.module}))
         end}
      end)

    document = %Document{file: Macro.expand(file, env), line: line, column: column, args: args}

    template
    |> :cinder_handlebars.parse()
    |> case do
      ast when is_list(ast) ->
        document
        |> compile_template(ast, [], env)
        |> Compilable.optimise(env)

      {_, _, {{:line, l}, {:column, c}}} = unparsed ->
        line = line + l
        column = column + c

        raise "Unable to compile template `#{file}` at line #{line}, column #{column}\n\n#{inspect(unparsed)}"
    end
  end

  defp compile_template(result, [], _, _env), do: result

  defp compile_template(parent, [{:doctype, contents} | ast], opts, env) do
    parent
    |> Compilable.add_child(Static.init(["<!DOCTYPE", contents, ">"]), opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:text, static} | ast], opts, env) do
    parent
    |> Compilable.add_child(Static.init(static), opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:component, name, attrs} | ast], opts, env) do
    component =
      Component.init(name)
      |> compile_template(Enum.map(attrs, &{:attr, &1}), [:attr | opts], env)

    parent
    |> Compilable.add_child(component, opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:component, name, attrs, content} | ast], opts, env) do
    component =
      Component.init(name)
      |> compile_template(Enum.map(attrs, &{:attr, &1}), opts, env)
      |> compile_template(content, opts, env)

    parent
    |> Compilable.add_child(component, opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:slot, name, content} | ast], opts, env) do
    parent
    |> compile_template(content, [{:slot, name} | opts], env)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:element, name, attrs} | ast], opts, env) do
    element =
      VoidElement.init(name)
      |> compile_template(Enum.map(attrs, &{:attr, &1}), opts, env)

    parent
    |> Compilable.add_child(element, opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:element, name, attrs, children} | ast], opts, env) do
    element =
      Element.init(name)
      |> compile_template(Enum.map(attrs, &{:attr, &1}), opts, env)
      |> compile_template(children, opts, env)

    parent
    |> Compilable.add_child(element, opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:attr, {name, value}} | ast], opts, env)
       when (is_binary(value) and is_element(parent)) or is_struct(parent, Component) do
    parent
    |> Compilable.add_child(Attribute.init(name, value), opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:attr, {name, {:expr, _} = expr}} | ast], opts, env)
       when is_element(parent) do
    expr = compile_expr(expr, env)

    parent
    |> Compilable.add_child(Attribute.init(name, expr), opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:expr, :yield} | ast], opts, env),
    do: compile_template(parent, [{:expr, {:yield, []}} | ast], opts, env)

  defp compile_template(parent, [{:expr, {:yield, _args}} = expr | ast], opts, env) do
    expr =
      expr
      |> compile_expr(env)
      |> RawExpression.init()

    parent
    |> Compilable.add_child(expr, opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:expr, _} = expr | ast], opts, env) do
    expr =
      expr
      |> compile_expr(env)
      |> Expression.init()

    parent
    |> Compilable.add_child(expr, opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(parent, [{:safe_expr, expr} | ast], opts, env) do
    expr =
      {:expr, expr}
      |> compile_expr(env)
      |> RawExpression.init()

    parent
    |> Compilable.add_child(expr, opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_template(
         parent,
         [{:block, _, _, positive, negative, bindings} = block | ast],
         opts,
         env
       ) do
    block =
      block
      |> compile_expr(env)
      |> Block.init()
      |> compile_template(positive, [{:stage, :positive} | opts], env)
      |> compile_template(negative, [{:stage, :negative} | opts], env)

    parent
    |> Compilable.add_child(%{block | bindings: bindings}, opts)
    |> compile_template(ast, opts, env)
  end

  defp compile_expr({:block, :if, args, positive, negative, bindings}, env),
    do: compile_expr({:block, :block_if, args, positive, negative, bindings}, env)

  defp compile_expr({:block, :unless, args, positive, negative, bindings}, env),
    do: compile_expr({:block, :block_unless, args, positive, negative, bindings}, env)

  defp compile_expr({:block, :yield, args, _positive, _negative, _bindings}, env) do
    slot_name =
      args
      |> compile_args(env)
      |> case do
        [] -> "default"
        [slot_name | _] -> to_string(slot_name)
      end

    quote generated: true, context: env.module do
      with {nil, _} <- Assigns.pop(slots, unquote(slot_name)),
           {nil, _} <- Assigns.pop(slots, "positive") do
        raise RuntimeError, "Slot `#{unquote(slot_name)}` is missing."
      else
        {slot, slots} -> Render.execute(slot, assigns, slots, locals)
      end
    end
  end

  defp compile_expr({:block, fun, args, _, _, []}, env) do
    quote generated: true, context: env.module do
      unquote(fun)(unquote_splicing(compile_args(args, env)))
    end
  end

  defp compile_expr({:block, fun, args, _, _, bindings}, env) do
    quote generated: true, context: env.module do
      unquote(fun)(unquote_splicing(compile_args(args, env)), unquote(bindings))
    end
  end

  defp compile_expr({:expr, {:path, segments}}, env), do: compile_arg({:path, segments}, env)
  defp compile_expr({:expr, {:@, assign}}, env), do: compile_arg({:@, assign}, env)

  defp compile_expr({:expr, {:yield, args}}, env) when is_list(args) do
    slot_name =
      args
      |> compile_args(env)
      |> case do
        [] -> "default"
        [slot_name | _] -> to_string(slot_name)
      end

    quote generated: true, context: env.module do
      case Assigns.pop(slots, unquote(slot_name)) do
        {nil, _} ->
          raise RuntimeError, "Slot `#{unquote(slot_name)}` is missing."

        {slot, slots} ->
          Render.execute(slot, assigns, slots, locals)
      end
    end
  end

  defp compile_expr({:expr, {fun, args}}, env) when is_atom(fun) and is_list(args) do
    quote context: env.module, generated: true do
      unquote(fun)(unquote_splicing(compile_args(args, env)))
    end
  end

  defp compile_expr({:expr, ident}, env) when is_atom(ident), do: compile_arg(ident, env)
  defp compile_expr({:expr, number}, env) when is_number(number), do: compile_arg(number, env)
  defp compile_expr({:expr, string}, env) when is_binary(string), do: compile_arg(string, env)
  defp compile_expr({:expr, boolean}, env) when is_binary(boolean), do: compile_arg(boolean, env)

  defp compile_args(args, env) when is_list(args), do: compile_args(args, [], [], env)
  defp compile_args([], [], args, _env), do: Enum.reverse(args)
  defp compile_args([], keywords, args, _env), do: Enum.reverse([keywords | args])

  defp compile_args([next | remaining], keywords, args, env) do
    case compile_arg(next, env) do
      {key, value} when is_atom(key) ->
        compile_args(remaining, Keyword.put(keywords, key, value), args, env)

      value ->
        compile_args(remaining, keywords, [value | args], env)
    end
  end

  defp compile_arg({:expr, _} = expr, env), do: compile_expr(expr, env)
  defp compile_arg({:=, key, value}, env), do: {key, compile_arg(value, env)}

  defp compile_arg({:@, ident}, env) do
    quote context: env.module, generated: true do
      case Access.fetch(assigns, unquote(ident)) do
        {:ok, value} ->
          value

        :error ->
          raise UnknownAssignError,
            assign: unquote(ident),
            file: unquote(env.file),
            line: unquote(env.line)
      end
    end
  end

  defp compile_arg({:path, [root | segments]}, env) do
    segments
    |> Enum.reduce(compile_arg(root, env), fn
      segment, parent when is_atom(segment) or is_binary(segment) ->
        quote context: env.module, generated: true do
          case Access.fetch(unquote(parent), unquote(segment)) do
            {:ok, value} ->
              value

            :error ->
              raise IndexError,
                parent: unquote(parent),
                segment: unquote(segment),
                file: unquote(env.file),
                line: unquote(env.line)
          end
        end

      segment, parent when is_integer(segment) and segment >= 0 ->
        quote context: env.module, generated: true do
          case Enum.fetch(unquote(parent), unquote(segment)) do
            {:ok, value} ->
              value

            :error ->
              raise IndexError,
                parent: unquote(parent),
                segment: unquote(segment),
                file: unquote(env.file),
                line: unquote(env.line)
          end
        end
    end)
  end

  defp compile_arg(boolean, env) when is_boolean(boolean) do
    quote context: env.module, generated: true do
      unquote(boolean)
    end
  end

  defp compile_arg(special, env) when special in ~w[null undefined]a do
    quote context: env.module, generated: true do
      nil
    end
  end

  defp compile_arg(ident, env) when is_atom(ident) do
    quote context: env.module, generated: true do
      case Access.fetch(locals, unquote(ident)) do
        {:ok, value} ->
          value

        :error ->
          raise UnknownLocalError,
            local: unquote(ident),
            file: unquote(env.file),
            line: unquote(env.line)
      end
    end
  end

  defp compile_arg(number, _env) when is_number(number), do: number
  defp compile_arg(string, _env) when is_binary(string), do: string
  defp compile_arg(binary, _env) when is_binary(binary), do: binary
end
