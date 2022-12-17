spark_locals_without_parens = [
  base_path: 1,
  cookie_signing_salt: 1,
  listen_port: 1,
  plug: 1,
  plug: 2,
  plug: 3,
  resource: 1,
  route: 2,
  route: 3,
  secret_key_base: 1
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
