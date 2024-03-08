defmodule Cinder.Component.Dsl.Info do
  @moduledoc """
  Auto-generated introspection for Cinder components.
  """

  alias Cinder.Component.{Dsl, Dsl.Event, Dsl.Property, Dsl.Slot}
  alias Spark.{Dsl.Extension, InfoGenerator}

  use InfoGenerator, extension: Dsl, sections: [:component]

  @type dsl_or_component :: module | map

  @doc """
  Returns a list of all the properties defined for a component.
  """
  @spec properties(dsl_or_component()) :: [Property.t()]
  def properties(component) do
    component
    |> Extension.get_entities([:component])
    |> Enum.filter(&is_struct(&1, Property))
  end

  @doc """
  Returns a specific named property of a component.
  """
  @spec property(dsl_or_component(), atom) :: {:ok, Property.t()} | :error
  def property(component, name) do
    component
    |> Extension.get_entities([:component])
    |> Enum.find_value(:error, fn
      %Property{name: ^name} = property -> {:ok, property}
      _ -> false
    end)
  end

  @doc """
  Returns a list of all the slots defined for a component.
  """
  @spec slots(dsl_or_component()) :: [Slot.t()]
  def slots(component) do
    component
    |> Extension.get_entities([:component])
    |> Enum.filter(&is_struct(&1, Slot))
  end

  @doc """
  Returns a specific named slot of a component.
  """
  @spec slot(dsl_or_component(), atom) :: {:ok, Slot.t()} | :error
  def slot(component, name) do
    component
    |> Extension.get_entities([:component])
    |> Enum.find_value(:error, fn
      %Slot{name: ^name} = slot -> {:ok, slot}
      _ -> false
    end)
  end

  @doc """
  Should the contents of the slot have their whitespace trimmed?
  """
  @spec trim_slot?(dsl_or_component(), atom) :: boolean
  def trim_slot?(component, name) do
    component
    |> slot(name)
    |> case do
      {:ok, %{trim?: true}} -> true
      _ -> false
    end
  end

  @doc """
  Returns a list of all the events defined for a component.
  """
  @spec events(dsl_or_component()) :: [Event.t()]
  def events(component) do
    component
    |> Extension.get_entities([:component])
    |> Enum.filter(&is_struct(&1, Event))
  end

  @doc """
  Returns a specific named event of a component.
  """
  @spec event(dsl_or_component(), atom) :: {:ok, Event.t()} | :error
  def event(component, name) do
    component
    |> Extension.get_entities([:component])
    |> Enum.find_value(:error, fn
      %Event{name: ^name} = event -> {:ok, event}
      _ -> false
    end)
  end
end
