defmodule Cinder.Dsl do
  alias Cinder.{Dsl, Engine, Plug, Route, Template}
  alias Spark.Dsl.{Entity, Section}

  @moduledoc """
  The Cinder DSL.

  This is consumed by `spark` to generate the DSL functions and validations.
  """

  @route %Entity{
    name: :route,
    args: [:name, :path],
    target: Dsl.Route,
    recursive_as: :children,
    schema: [
      name: [
        type: {:behaviour, Route},
        required: true
      ],
      path: [
        type: :string,
        required: true
      ],
      resource: [
        type: {:or, [{:spark_behaviour, Ash.Resource}, {:in, [nil]}]},
        default: nil
      ]
    ],
    entities: [children: []]
  }

  @plug %Entity{
    name: :plug,
    args: [:name, {:optional, :options, []}],
    target: Dsl.Plug,
    schema: [
      name: [
        type: {:or, [{:behaviour, Plug}, :atom]},
        required: true
      ],
      options: [
        type: :keyword_list,
        required: false,
        default: []
      ]
    ]
  }

  @dsl [
    %Section{
      name: :cinder,
      describe: "Configuration for a Cinder application",
      sections: [
        %Section{
          name: :router,
          describe: "The router",
          entities: [@route]
        },
        %Section{
          name: :templates,
          describe: "Templating options",
          schema: [
            base_path: [
              type: {:or, [:string, {:struct, Path}]}
            ]
          ]
        },
        %Section{
          name: :pipeline,
          describe: "A plug pipeline applied to incoming requests",
          entities: [@plug]
        },
        %Section{
          name: :engine,
          describe: "Settings related to the Cinder engine",
          schema: [
            server_idle_timeout: [
              type: :pos_integer,
              doc: "Server idle timeout in seconds",
              default: 300
            ]
          ]
        }
      ],
      schema: [
        secret_key_base: [
          type:
            {:or,
             [{:spark_function_behaviour, Cinder.Secret, {Cinder.Secret.AnonFn, 1}}, :string]},
          doc: "Secret key for signing requests",
          required: true
        ],
        cookie_signing_salt: [
          type: :string,
          required: true
        ],
        listen_port: [
          type: :pos_integer,
          doc: "HTTP listen port",
          default: 4000
        ]
      ]
    }
  ]

  use Spark.Dsl.Extension,
    sections: @dsl,
    transformers: [Engine.Transformer, Plug.Transformer, Route.Transformer, Template.Transformer]

  @doc false
  @spec dsl :: [Section.t()]
  def dsl, do: @dsl
end