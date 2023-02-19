defmodule Cinder.Component.Dsl do
  @moduledoc """
  DSL definitions for Cinder.Component.
  """

  alias Cinder.Component.{
    Dsl.Event,
    Dsl.Property,
    Dsl.Slot,
    Dsl.Transformer,
    Script
  }

  alias Spark.Dsl.{Entity, Extension, Section}

  @component %Section{
    name: :component,
    describe: "Component settings",
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
          ],
          allow_nil?: [
            type: :boolean,
            required: false,
            default: true
          ],
          data?: [
            type: :boolean,
            required: false,
            default: false
          ]
        ]
      },
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
      },
      %Entity{
        name: :event,
        args: [:name, :script],
        target: Event,
        schema: [
          name: [
            type: :atom,
            required: true
          ],
          script: [
            type: {:struct, Script},
            required: true
          ]
        ]
      }
    ]
  }

  use Extension, sections: [@component], transformers: [Transformer]

  @doc false
  @spec dsl :: [Section.t()]
  def dsl, do: [@component]
end
