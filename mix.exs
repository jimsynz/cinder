defmodule Cinder.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.1.0"
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
      elixirc_paths: elixirc_paths(Mix.env())
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
      {:credo, "~> 1.6", only: ~w[dev test]a},
      {:doctor, "~> 0.21", only: ~w[dev test]a},
      {:ex_doc, ">= 0.28.0", only: ~w[dev test]a},
      {:git_ops, "~> 2.5", only: ~w[dev test]a, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
