import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://code.harton.nz/james/cinder",
  manage_mix_version?: true,
  version_tag_prefix: "v",
  manage_readme_version: "README.md"

config :esbuild,
  version: "0.16.4",
  prod: [
    args: ~w(ts/cinder.ts --bundle --target=es2016 --outdir=../priv/static),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("./node_modules", __DIR__)}
  ]

import_config "#{config_env()}.exs"
