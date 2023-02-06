defmodule Cinder.Component.Dsl do
  @moduledoc """
  DSL definitions for Cinder.Component.
  """

  alias Cinder.Component.Dsl.{Property, Slot, Transformer}
  alias Spark.Dsl.{Entity, Extension, Section}

  @properties %Section{
    name: :properties,
    describe: "Properties which can be passed to this component",
    schema: [],
    entities: [
      %Entity{
        name: :prop,
        args: [:name, :type],
        target: Property,
        schema: [
          name: [
            type: :atom,
            required: true
          ],
          type: [
            type: :any,
            doc: "A type as per NimbleOptions",
            required: true
          ],
          required?: [
            type: :boolean,
            required: false,
            default: true
          ]
        ]
      }
    ]
  }

  @slots %Section{
    name: :slots,
    describe: "Slots which can be passed to this component",
    schema: [],
    entities: [
      %Entity{
        name: :slot,
        args: [{:optional, :name, :default}],
        target: Slot,
        schema: [
          name: [
            type: {:or, [{:in, [:default]}, :string]}
          ],
          required?: [
            type: :boolean,
            default: true
          ]
        ]
      }
    ]
  }

  use Extension, sections: [@properties, @slots], transformers: [Transformer]

  @doc false
  @spec dsl :: [Section.t()]
  def dsl, do: [@properties, @slots]
end
