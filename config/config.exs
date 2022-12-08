import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://gitlab.com/jimsy/cinder",
  manage_mix_version?: true,
  version_tag_prefix: "v"
