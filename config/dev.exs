import Config

config :ecto_tenant, tenant_repos: [Repo]

config :ecto_tenant, Repo,
  host: "locahost",
  port: 5432,
  username: "postgres",
  tenants: [
    [id: :foo, prefix: "client_foo", repo: :one],
    [id: :bar, prefix: "client_bar", repo: :two]
  ],
  repos: [
    [name: :one, database: "tenant_one_dev"],
    [name: :two, database: "tenant_two_dev"]
  ]
