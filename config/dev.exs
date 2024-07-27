import Config

config :ecto_tenant, ecto_tenant_repos: [Repo]

config :ecto_tenant, Repo,
  hostname: "postgres",
  username: "postgres",
  port: 5432,
  tenants: [
    [name: "foo", prefix: "client_foo", dynamic_repo: :one],
    [name: "bar", prefix: "client_bar", dynamic_repo: :two]
  ],
  dynamic_repos: [
    [name: :one, database: "tenant_one_dev"],
    [name: :two, database: "tenant_two_dev"]
  ]

config :ecto_tenant, SingleDbRepo,
  hostname: "postgres",
  username: "postgres",
  database: "single_db_repo_dev",
  port: 5432,
  tenants: [
    [name: "foo", prefix: "tenant_foo"],
    [name: "bar", prefix: "tenant_bar"],
  ]
