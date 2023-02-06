defmodule Cinder.Template.Rendered.Component do
  @moduledoc """
  A cinder component.
  """

  defstruct name: [], attributes: [], slots: %{}, renderer: nil

  alias Cinder.{
    Errors.Component.MissingPropertyError,
    Errors.Component.PropertyValidationError,
    Template,
    Template.Assigns,
    Template.Compilable,
    Template.Macros,
    Template.Render,
    Template.Rendered.Attribute,
    Template.Rendered.Component,
    Template.Rendered.Static
  }

  alias NimbleOptions.ValidationError

  alias Spark.Dsl.Extension

  @type t :: %Component{
          name: atom,
          attributes: [Attribute.t()],
          slots: %{required(atom | binary) => [Render.t()]},
          renderer: nil | Macro.t() | Template.renderer()
        }

  @spec init([binary]) :: t
  def init(name),
    do: %Component{name: name |> List.flatten() |> Enum.join(".") |> String.to_atom()}

  @doc """
  Validate the assigns match the properties defined in the component definition.
  """
  @spec validate_props(module, Assigns.t()) :: :ok | no_return()
  def validate_props(module, props) do
    module
    |> Extension.get_entities([:properties])
    |> Enum.each(fn property ->
      with {:ok, prop} <- Access.fetch(props, property.name),
           {:ok, _} <-
             NimbleOptions.validate([{property.name, prop}], [
               {property.name, [type: property.type, required: true]}
             ]) do
        :ok
      else
        {:error, %ValidationError{}} ->
          raise PropertyValidationError,
            component: module,
            property: property.name,
            type: property.type,
            file: __ENV__.file,
            line: __ENV__.line

        :error ->
          if property.required? do
            raise MissingPropertyError,
              component: module,
              property: property.name,
              file: __ENV__.file,
              line: __ENV__.line
          else
            :ok
          end
      end
    end)

    :ok
  end

  defimpl Compilable do
    @doc false
    @spec add_child(Component.t(), Compilable.t(), [atom | {atom, any}]) :: Component.t()
    def add_child(component, child, [:attr | _]),
      do: %{component | attributes: [child | component.attributes]}

    def add_child(component, child, [{:slot, slot} | _]),
      do: %{component | slots: Map.update(component.slots, slot, [child], &[child | &1])}

    def add_child(component, child, opts),
      do: add_child(component, child, [{:slot, "default"} | opts])

    @doc false
    @spec dynamic?(Component.t()) :: boolean
    def dynamic?(component) do
      Enum.any?(component.attributes, &Compilable.dynamic?/1) ||
        Enum.any?(Map.values(component.slots), &Compilable.dynamic?/1)
    end

    @doc false
    @spec optimise(Component.t(), Macro.Env.t()) :: Component.t()
    def optimise(component, _env) when is_function(component.renderer, 3), do: component
    def optimise(%{renderer: {:fn, _, _}} = component, _env), do: component

    def optimise(component, env) do
      slots =
        component.slots
        |> Enum.map(fn {name, children} ->
          children =
            if Enum.any?(children, &Compilable.dynamic?/1) do
              children
              |> Enum.reverse()
              |> Enum.map(&Compilable.optimise(&1, env))
              |> Static.optimise_sequence()
            else
              children
              |> Enum.reverse()
              |> Enum.map(&Render.render/1)
              |> Static.init()
              |> List.wrap()
            end

          {name, children}
        end)

      attributes =
        component.attributes
        |> Enum.reverse()
        |> Enum.map(fn attribute ->
          {attribute.name, attribute.value}
        end)
        |> Map.new()

      module =
        case Macro.Env.fetch_alias(env, component.name) do
          {:ok, alias} -> Module.concat([alias])
          :error -> Module.concat([component.name])
        end

      component = %{component | name: module, attributes: attributes, slots: slots}

      fun =
        quote context: env.module, generated: true do
          fn parent_assigns, slots, locals ->
            assigns =
              unquote(Macros.escape(attributes))
              |> Enum.reduce(Assigns.init(), fn
                {name, value}, assigns when is_binary(value) ->
                  assign(assigns, name, value)

                {name, value}, assigns when is_function(value, 3) ->
                  assign(assigns, name, value.(parent_assigns, slots, locals))
              end)

            Component.validate_props(unquote(module), assigns)

            slots =
              Enum.reduce(unquote(Macros.escape(slots)), slots, fn {name, children}, slots ->
                assign(slots, name, children)
              end)

            unquote(module).render()
            |> Render.execute(assigns, slots, locals)
          end
        end

      %{component | renderer: fun}
    end
  end

  defimpl Render do
    @doc false
    @spec render(Component.t()) :: Render.render_list()
    def render(component), do: component.module.render() |> Render.render()

    # I have no idea why the return type above doesn't match. If you know,
    # please get in touch.
    @dialyzer {:nowarn_function, render: 1}

    @doc false
    @spec execute(Component.t(), Assigns.t(), Assigns.t(), Assigns.t()) :: iodata
    def execute(component, assigns, slots, locals),
      do: component.renderer.(assigns, slots, locals)
  end
end
