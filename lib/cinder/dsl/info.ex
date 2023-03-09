defmodule Cinder.Dsl.Info do
  @moduledoc """
  Auto-generated introspection for Cinder apps.
  """
  use Spark.InfoGenerator, extension: Cinder.Dsl, sections: [:cinder]

  alias Spark.Dsl.Extension

  @type dsl_or_app :: module | Spark.Dsl.t()

  @doc "Retrieve the asset target  path"
  @spec asset_target_path(dsl_or_app) :: binary
  def asset_target_path(app), do: Extension.get_persisted(app, :cinder_assets_target_path)

  @doc "Retrieve the asset source path"
  @spec asset_source_path(dsl_or_app) :: binary
  def asset_source_path(app), do: Extension.get_persisted(app, :cinder_assets_source_path)

  @doc "Retrieve the route namespace"
  @spec cinder_route_namespace(dsl_or_app) :: binary
  def cinder_route_namespace(app), do: Extension.get_persisted(app, :cinder_route_namespace)

  @doc "Retrieve a route entity by it's module"
  @spec fetch_route_by_module(dsl_or_app, module) :: {:ok, atom} | :error
  def fetch_route_by_module(dsl_or_app, route_module) do
    dsl_or_app
    |> Extension.get_persisted(:cinder_route_map)
    |> Map.fetch(route_module)
  end

  @doc "Retrieve a route entity by it's short name"
  @spec fetch_route_by_short_name(dsl_or_app, atom) :: {:ok, atom} | :error
  def fetch_route_by_short_name(dsl_or_app, short_name) do
    dsl_or_app
    |> Extension.get_persisted(:cinder_route_short_name_map)
    |> Map.fetch(short_name)
    |> case do
      {:ok, module} -> fetch_route_by_module(dsl_or_app, module)
      :error -> :error
    end
  end
end
