defmodule Cinder.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.9.3"
  @description "An experimental web application server."

  def project do
    [
      app: :cinder,
      version: @version,
      description: @description,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      compilers: compilers(Mix.env()),
      preferred_cli_env: [ci: :test],
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit, :iex],
        list_unused_filters: true
      ],
      docs: [
        main: "readme",
        extra_section: "Guides",
        formatters: ["html"],
        filter_modules: ~r/^Elixir.Cinder/,
        source_url_pattern: "https://harton.dev/cinder/cinder/src/branch/main/%{path}#L%{line}",
        spark: [
          extensions: [
            %{
              module: Cinder.Dsl,
              name: "Cinder.Dsl",
              target: "Cinder",
              type: "Cinder"
            },
            %{
              module: Cinder.Component.Dsl,
              name: "Cinder.Component.Dsl",
              target: "Cinder.Component",
              type: "Cinder.Component"
            }
          ]
        ],
        extras:
          ["README.md"]
          |> Enum.concat(Path.wildcard("documentation/**/*.{md,livemd,cheatmd}"))
          |> Enum.map(fn
            "README.md" -> {:"README.md", title: "Read Me", ash_hq?: false}
            "documentation/" <> _ = path -> {String.to_atom(path), []}
          end),
        groups_for_extras:
          "documentation/*"
          |> Path.wildcard()
          |> Enum.map(fn dir ->
            name =
              dir
              |> Path.split()
              |> List.last()
              |> String.split(~r/_+/)
              |> Enum.map_join(" ", &String.capitalize/1)

            files =
              dir
              |> Path.join("**.{md,livemd,cheatmd}")
              |> Path.wildcard()

            {name, files}
          end)
      ]
    ]
  end

  def package do
    [
      maintainers: ["James Harton <james@harton.nz>"],
      licenses: ["HL3-FULL"],
      links: %{
        "Source" => "https://harton.dev/cinder/cinder"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger, :esbuild],
      mod: {Cinder.Application, []}
    ]
  end

  defp deps do
    [
      {:ip, "~> 2.0 and >= 2.0.1"},
      {:jason, "~> 1.4"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.6"},
      {:spark, "~> 1.1 and >= 1.1.18"},

      # dev/test
      {:credo, "~> 1.6", only: ~w[dev test]a, runtime: false},
      # {:doctor, "~> 0.21", only: ~w[dev test]a, runtime: false},
      {:doctor, github: "akoutmos/doctor", only: ~w[dev test]a, runtime: false},
      {:dialyxir, "~> 1.2", only: ~w[dev test]a, runtime: false},
      {:esbuild, "~> 0.8.0", only: ~w[dev test]a},
      {:ex_check, "~> 0.15", only: ~w[dev test]a, runtime: false},
      {:ex_doc, ">= 0.28.0", only: ~w[dev test]a, runtime: false},
      {:git_ops, "~> 2.5", only: ~w[dev test]a, runtime: false},
      {:tailwind, "~> 0.2.0", only: :dev},
      {:mix_audit, "~> 2.1", only: ~w[dev test]a, runtime: false},
      {:sobelow, "~> 0.13", only: ~w[dev test]a, runtime: false},
      {:neotoma_compiler,
       git: "https://harton.dev/james/neotoma_compiler.git",
       branch: "main",
       only: ~w[dev test]a,
       runtime: false}
    ]
  end

  defp aliases,
    do: [
      "spark.formatter": "spark.formatter --extensions=Cinder.Dsl,Cinder.Component.Dsl",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions=Cinder.Dsl,Cinder.Component.Dsl"
    ]

  defp compilers(env) when env in ~w[dev test]a, do: [:neotoma | Mix.compilers()]
  defp compilers(_env), do: Mix.compilers()

  defp elixirc_paths(env) when env in ~w[dev test]a, do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
