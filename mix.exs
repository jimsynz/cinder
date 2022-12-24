defmodule Cinder.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.5.0"
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
      licenses: ["Hippocratic"],
      links: %{
        "Source" => "https://gitlab.com/jimsy/cinder"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Cinder.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.6"},
      {:spark, "~> 0.3.1"},
      {:credo, "~> 1.6", only: ~w[dev test]a, runtime: false},
      {:doctor, "~> 0.21", only: ~w[dev test]a, runtime: false},
      {:dialyxir, "~> 1.2", only: ~w[dev test]a, runtime: false},
      {:esbuild, "~> 0.6.0", only: ~w[dev test]a},
      {:ex_doc, ">= 0.28.0", only: ~w[dev test]a, runtime: false},
      {:git_ops, "~> 2.5", only: ~w[dev test]a, runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "doctor --full --raise",
        "credo --strict",
        "dialyzer",
        "hex.audit",
        "test"
      ]
      # docs: ["docs", "ash.replace_doc_links"],
      # test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
