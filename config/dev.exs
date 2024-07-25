import Config

config :ecto_tenant, ecto_tenant_repos: [Repo]

config :ecto_tenant, Repo,
  hostname: "0.0.0.0",
  username: "postgres",
  port: 5432,
  tenants: [
    [name: "foo", prefix: "client_foo", repo: :one],
    [name: "bar", prefix: "client_bar", repo: :two]
  ],
  repos: [
    [name: :one, database: "tenant_one_dev"],
    [name: :two, database: "tenant_two_dev"]
  ]
