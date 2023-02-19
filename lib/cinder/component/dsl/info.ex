defmodule Cinder.Component.Dsl.Info do
  @moduledoc """
  Auto-generated introspection for Cinder components.
  """
  use Spark.InfoGenerator, extension: Cinder.Component.Dsl, sections: [:component]

  alias Cinder.Component.Dsl.{Event, Property, Slot}

  @type dsl_or_component :: module | map

  @doc """
  Retrieve all events from the component DSL.
  """
  @spec events(dsl_or_component) :: [Event.t()]
  def events(dsl_or_component) do
    dsl_or_component
    |> component()
    |> Enum.filter(&is_struct(&1, Event))
  end

  @doc """
  Retrieve all properties from the component DSL.
  """
  @spec properties(dsl_or_component) :: [Property.t()]
  def properties(dsl_or_component) do
    dsl_or_component
    |> component()
    |> Enum.filter(&is_struct(&1, Property))
  end

  @doc """
  Retrieve all slots from the component DSL.
  """
  @spec slots(dsl_or_component) :: [Slot.t()]
  def slots(dsl_or_component) do
    dsl_or_component
    |> component()
    |> Enum.filter(&is_struct(&1, Slot))
  end
end
