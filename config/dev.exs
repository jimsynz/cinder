import Config

config :cinder,
  secret_key_base:
    "rx7KrY6qDhKONx80pIAyki8bWJ5NkqOvrAG5xbkM+p+OLrUqtk4Cfd+S1YT40F8JIKEKFM0LbcSVGHyC2wq3uA"

config :esbuild,
  version: "0.16.4",
  dev: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../test/support/example/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.2.4",
  dev: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../static/assets/app.css
    ),
    cd: Path.expand("../test/support/example/assets", __DIR__)
  ]
