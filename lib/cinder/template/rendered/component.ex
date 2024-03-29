defmodule Cinder.Template.Rendered.Component do
  @moduledoc """
  A cinder component.
  """

  defstruct attributes: [], name: [], optimised?: false, slots: %{}

  alias Cinder.{
    Component.Dsl.Info,
    Template.Assigns,
    Template.Compilable,
    Template.Render,
    Template.Rendered.AssignCompose,
    Template.Rendered.Attribute,
    Template.Rendered.Component,
    Template.Rendered.Static,
    Template.Rendered.TrimCompose,
    Template.SlotStack
  }

  @type t :: %Component{
          attributes: [Attribute.t()],
          name: atom,
          optimised?: boolean,
          slots: %{required(atom) => [Render.t()]}
        }

  @doc false
  @spec init([binary]) :: t
  # sobelow_skip ["DOS.StringToAtom"]
  def init(name),
    do: %Component{name: name |> List.flatten() |> Enum.join(".") |> String.to_atom()}

  defimpl Compilable do
    @doc false
    @spec add_child(Component.t(), Compilable.t(), [atom | {atom, any}]) :: Component.t()
    def add_child(component, child, [:attr | _]),
      do: %{component | attributes: [child | component.attributes]}

    def add_child(component, child, [{:slot, slot} | _]),
      do: %{component | slots: Map.update(component.slots, slot, [child], &[child | &1])}

    def add_child(component, child, opts),
      do: add_child(component, child, [{:slot, :default} | opts])

    @doc false
    @spec dynamic?(Component.t()) :: boolean
    def dynamic?(_component), do: true

    @doc false
    @spec optimise(Component.t(), Macro.Env.t()) :: Component.t()
    def optimise(component, _env) when component.optimised? == true, do: component

    def optimise(component, env) do
      slots =
        component.slots
        |> Enum.map(fn {name, children} ->
          children =
            if Enum.any?(children, &Compilable.dynamic?/1) do
              children
              |> Enum.reverse()
              |> Enum.map(&Compilable.optimise(&1, env))
              |> Static.optimise_sequences()
              |> Enum.map(&Compilable.optimise(&1, env))
            else
              children
              |> Enum.reverse()
              |> Enum.map(&Render.render/1)
              |> Static.init()
              |> List.wrap()
              |> Enum.map(&Compilable.optimise(&1, env))
            end

          {name, children}
        end)
        |> Map.new()

      module =
        case Macro.Env.fetch_alias(env, component.name) do
          {:ok, alias} -> Module.concat([alias])
          :error -> Module.concat([component.name])
        end

      attributes =
        component.attributes
        |> Enum.reverse()
        |> Enum.map(&Compilable.optimise(&1, env))

      %{
        component
        | name: module,
          attributes: attributes,
          slots: slots,
          optimised?: true
      }
    end
  end

  defimpl Render do
    alias Cinder.Template.{Assigns, SlotStack}
    @dialyzer {:nowarn_function, render: 1}

    @doc false
    @spec render(Component.t()) :: Render.render_list()
    def render(component), do: component.name.render() |> Render.render()

    @doc false
    @spec execute(Component.t(), Assigns.t(), SlotStack.t(), Assigns.t()) :: iodata
    def execute(component, parent_assigns, slots, locals) do
      assigns =
        if Assigns.has_key?(parent_assigns, :request) do
          Assigns.init(request: parent_assigns[:request])
        else
          Assigns.init()
        end

      assigns =
        component.attributes
        |> Enum.reduce(assigns, fn
          %{name: name, value: value}, assigns when is_binary(value) ->
            Assigns.push(assigns, name, value)

          %{name: name, value: value}, assigns when is_function(value, 3) ->
            Assigns.push(assigns, name, value.(parent_assigns, slots, locals))
        end)

      slots =
        component.slots
        |> Map.new(fn {name, slot} ->
          slot =
            if Info.trim_slot?(component.name, name),
              do: TrimCompose.init(slot),
              else: slot

          {name, AssignCompose.init(slot, parent_assigns)}
        end)
        |> then(&SlotStack.push(slots, &1))

      with :ok <- Cinder.Component.validate_props(component.name, assigns),
           :ok <- Cinder.Component.validate_slots(component.name, slots) do
        component.name.render()
        |> Render.execute(assigns, slots, locals)
      else
        {:error, reason} -> raise reason
      end
    end
  end
end
