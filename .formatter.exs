spark_locals_without_parens = [
  allow_nil?: 1,
  base_path: 1,
  bind_address: 1,
  cookie_signing_salt: 1,
  data?: 1,
  default: 1,
  event: 2,
  event: 3,
  listen_port: 1,
  plug: 1,
  plug: 2,
  plug: 3,
  prop: 2,
  prop: 3,
  reconnect_timeout: 1,
  required?: 1,
  route: 2,
  route: 3,
  secret_key_base: 1,
  short_name: 1,
  slot: 0,
  slot: 1,
  slot: 2,
  source_path: 1,
  target_path: 1,
  trim?: 1
]

[
  import_deps: [:spark],
  inputs: [
    "*.{ex,exs}",
    "{dev,config,lib,test}/**/*.{ex,exs}"
  ],
  plugins: [Spark.Formatter],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
