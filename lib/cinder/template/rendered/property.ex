defmodule Cinder.Template.Rendered.Property do
  @moduledoc """
  An attribute passed to a component.
  """

  defstruct name: nil, value: nil, optimised?: false

  alias Cinder.{
    Template,
    Template.Compilable,
    Template.Rendered.Property
  }

  @type t :: %Property{
          name: binary,
          value: nil | binary | Macro.t() | Template.renderer(),
          optimised?: boolean
        }

  @doc false
  @spec init(binary, binary | Macro.t()) :: t
  def init(name, value), do: %Property{name: name, value: value}

  defimpl Compilable do
    @doc false
    @spec add_child(Property.t(), Compilable.t(), keyword) :: Property.t()
    def add_child(node, _, _), do: node

    @doc false
    @spec dynamic?(Property.t()) :: boolean
    def dynamic?(node) when is_binary(node.value), do: false
    def dynamic?(_node), do: true

    @doc false
    @spec optimise(Property.t(), Macro.Env.t()) :: Property.t()
    def optimise(prop, _) when prop.optimised? == true, do: prop
    def optimise(prop, _env) when is_binary(prop.value), do: %{prop | optimised?: true}

    def optimise(prop, env) do
      value = prop.value

      fun =
        quote context: env.module, generated: true do
          fn assigns, slots, locals ->
            unquote(value)
            |> then(fn
              fun when is_function(fun, 3) -> fun.(assigns, slots, locals)
              other -> other
            end)
          end
        end

      %{prop | value: fun, optimised?: true}
    end
  end
end
