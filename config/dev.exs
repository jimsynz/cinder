import Config

config :cinder,
  secret_key_base:
    "rx7KrY6qDhKONx80pIAyki8bWJ5NkqOvrAG5xbkM+p+OLrUqtk4Cfd+S1YT40F8JIKEKFM0LbcSVGHyC2wq3uA"

config :esbuild,
  version: "0.16.4",
  default: [
    args: ~w(ts/cinder.ts --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
