defmodule Cinder.Dsl.Info do
  @moduledoc """
  Auto-generated introspection for Cinder apps.
  """
  use Spark.InfoGenerator, extension: Cinder.Dsl, sections: [:cinder]

  alias Spark.Dsl.Extension

  @doc "Retrieve the asset target  path"
  @spec asset_target_path(dsl_or_app) :: binary when dsl_or_app: module | Spark.Dsl.t()
  def asset_target_path(app), do: Extension.get_persisted(app, :cinder_assets_target_path)

  @doc "Retrieve the asset source path"
  @spec asset_source_path(dsl_or_app) :: binary when dsl_or_app: module | Spark.Dsl.t()
  def asset_source_path(app), do: Extension.get_persisted(app, :cinder_assets_source_path)

  @doc "Retrieve the route namespace"
  @spec cinder_route_namespace(dsl_or_app) :: binary when dsl_or_app: module | Spark.Dsl.t()
  def cinder_route_namespace(app), do: Extension.get_persisted(app, :cinder_route_namespace)
end
