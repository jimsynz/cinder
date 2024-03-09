defmodule Cinder.Modules do
  @moduledoc """
  Define any missing modules at runtime.

  Since Cinder tries really hard to be super nice to you, and it also needs lots
  of modules defined (for routes and such).  We detect these modules at startup
  and create any that are missing.
  """

  alias Cinder.Dsl.Info

  @doc false
  @spec maybe_define_missing_modules(Cinder.app()) :: :ok
  def maybe_define_missing_modules(app) do
    if Info.cinder_auto_define_modules?(app) do
      define_missing_modules(app)
    end

    :ok
  end

  defp define_missing_modules(app) do
    engine = Info.app_engine_module(app)
    maybe_define_missing_behaviour(app, engine, Cinder.Engine)

    layout = Info.app_layout_module(app)
    maybe_define_missing_behaviour(app, layout, Cinder.Layout)

    plug = Info.app_plug_module(app)
    maybe_define_missing_behaviour(app, plug, Cinder.Plug)

    for route <- Info.app_route_modules(app) do
      maybe_define_missing_behaviour(app, route, Cinder.Route)
    end
  end

  defp maybe_define_missing_behaviour(app, module, behaviour) do
    unless Code.ensure_loaded?(module) do
      Module.create(
        module,
        quote do
          use unquote(behaviour), app: unquote(app)
        end,
        Macro.Env.location(__ENV__)
      )
    end
  end
end
