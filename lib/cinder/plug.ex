defmodule Cinder.Plug do
  @moduledoc """
  WAT
  """

  alias Cinder.{Dsl.Info, Secret}
  alias Spark.Dsl.Extension

  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :app)
    cookie_signing_salt = Secret.get_secret(app, [:cinder], :cookie_signing_salt)
    static_dir = Info.cinder_assets_target_path!(app)

    default_plugs = [
      {Plug.Static, [from: static_dir, at: "/"]},
      {Cinder.Plug.SetSecretKeyBase, [app: app]},
      {Plug.Session,
       [
         store: :cookie,
         key: "#{Macro.underscore(app)}_session",
         signing_salt: cookie_signing_salt,
         same_site: "Lax"
       ]},
      {:fetch_session, []},
      {Cinder.Plug.RequestId, [app: app]},
      {Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Jason},
      {Cinder.Plug.RequestHandler, [app: app]}
    ]

    user_plugs =
      app
      |> Extension.get_entities([:cinder, :pipeline])
      |> Enum.map(&{&1.name, &1.options})

    # by reversing before doing the uniq_by we ensure that anything the user has
    # set that conflicts with our defaults is chosen.
    plugs =
      default_plugs
      |> Enum.concat(user_plugs)
      |> Enum.reverse()
      |> Enum.uniq_by(&elem(&1, 0))
      |> Enum.reverse()

    quote location: :keep do
      use Plug.Builder
      import Plug.Conn

      for {name, options} <- unquote(plugs) do
        plug(name, options)
      end

      @doc false
      @spec __cinder_is__ :: {Cinder.Plug, unquote(app)}
      def __cinder_is__, do: {Cinder.Plug, unquote(app)}
    end
  end
end
