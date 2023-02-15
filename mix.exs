defmodule Cinder.MixProject do
  @moduledoc false
  use Mix.Project

  @version "1.1.0"
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
        plt_add_apps: [:mix, :ex_unit],
        list_unused_filters: true
      ]
    ]
  end

  def package do
    [
      maintainers: ["James Harton <james@harton.nz>"],
      licenses: ["HL3-FULL"],
      links: %{
        "Source" => "https://gitlab.com/jimsy/cinder"
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
      {:jason, "~> 1.4"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.6"},
      {:spark, "~> 0.4"},
      {:credo, "~> 1.6", only: ~w[dev test]a, runtime: false},
      # {:doctor, "~> 0.21", only: ~w[dev test]a, runtime: false},
      {:doctor, github: "akoutmos/doctor", only: ~w[dev test]a, runtime: false},
      {:dialyxir, "~> 1.2", only: ~w[dev test]a, runtime: false},
      {:esbuild, "~> 0.6.0", only: ~w[dev test]a},
      {:ex_check, "~> 0.15", only: ~w[dev test]a, runtime: false},
      {:ex_doc, ">= 0.28.0", only: ~w[dev test]a, runtime: false},
      {:git_ops, "~> 2.5", only: ~w[dev test]a, runtime: false},
      {:tailwind, "~> 0.1.9", only: :dev},
      {:mix_audit, "~> 2.1", only: ~w[dev test]a, runtime: false},
      {:sobelow, "~> 0.11", only: ~w[dev test]a, runtime: false},
      {:neotoma_compiler,
       git: "https://gitlab.com/jimsy/neotoma_compiler.git",
       branch: :main,
       only: ~w[dev test]a,
       runtime: false}
    ]
  end

  defp aliases, do: []

  defp compilers(env) when env in ~w[dev test]a, do: [:neotoma | Mix.compilers()]
  defp compilers(_env), do: Mix.compilers()

  defp elixirc_paths(env) when env in ~w[dev test]a, do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
