defmodule Mix.Tasks.Ecto.Tenant.Migrate do
  use Mix.Task
  import Mix.Ecto
  import Mix.EctoSQL

  @shortdoc "Runs the repository migrations"
  @default_opts [concurrency: 10]

  @aliases [
    n: :step,
    r: :repo,
    t: :tenant
  ]

  @switches [
    all: :boolean,
    step: :integer,
    to: :integer,
    to_exclusive: :integer,
    quiet: :boolean,
    tenant: [:keep, :string],
    concurrency: :integer,
    log_level: :string,
    log_migrations_sql: :boolean,
    log_migrator_sql: :boolean,
    strict_version_order: :boolean,
    repo: [:keep, :string],
    no_compile: :boolean,
    no_deps_check: :boolean,
    migrations_path: :keep
  ]

  @moduledoc """
  Runs the pending migrations for the given repository.

  Migrations are expected at "priv/YOUR_REPO/migrations" directory
  of the current application, where "YOUR_REPO" is the last segment
  in your repository name. For example, the repository `MyApp.Repo`
  will use "priv/repo/migrations". The repository `Whatever.MyRepo`
  will use "priv/my_repo/migrations".

  You can configure a repository to use another directory by specifying
  the `:priv` key under the repository configuration. The "migrations"
  part will be automatically appended to it. For instance, to use
  "priv/custom_repo/migrations":

      config :my_app, MyApp.Repo, priv: "priv/custom_repo"

  This task runs all pending migrations by default. To migrate up to a
  specific version number, supply `--to version_number`. To migrate a
  specific number of times, use `--step n`.

  The repositories to migrate are the ones specified under the
  `:ecto_repos` option in the current app configuration. However,
  if the `-r` option is given, it replaces the `:ecto_repos` config.

  Since Ecto tasks can only be executed once, if you need to migrate
  multiple repositories, set `:ecto_repos` accordingly or pass the `-r`
  flag multiple times.

  If a repository has not yet been started, one will be started outside
  your application supervision tree and shutdown afterwards.

  ## Examples

      $ mix ecto.migrate
      $ mix ecto.migrate -r Custom.Repo

      $ mix ecto.migrate -n 3
      $ mix ecto.migrate --step 3

      $ mix ecto.migrate --to 20080906120000

  ## Command line options

    * `--all` - run all pending migrations

    * `--log-migrations-sql` - log SQL generated by migration commands

    * `--log-migrator-sql` - log SQL generated by the migrator, such as
      transactions, table locks, etc

    * `--log-level` (since v3.11.0) - the level to set for `Logger`. This task
      does not start your application, so whatever level you have configured in
      your config files will not be used. If this is not provided, no level
      will be set, so that if you set it yourself before calling this task
      then this won't interfere. Can be any of the `t:Logger.level/0` levels

    * `--migrations-path` - the path to load the migrations from, defaults to
      `"priv/repo/migrations"`. This option may be given multiple times in which
      case the migrations are loaded from all the given directories and sorted
      as if they were in the same one

    * `--no-compile` - does not compile applications before migrating

    * `--no-deps-check` - does not check dependencies before migrating

    * `-c`, `--concurrency` - run migrations for tenants concurrently (defaults to 10)

    * `-t`, `--tenant` - the tenant name to run migrations on. If not specified,
      will run on all tenants. Can be specified multiple times.

    * `--quiet` - do not log migration commands

    * `-r`, `--repo` - the repo to migrate

    * `--step`, `-n` - run n number of pending migrations

    * `--strict-version-order` - abort when applying a migration with old
      timestamp (otherwise it emits a warning)

    * `--to` - run all migrations up to and including version

    * `--to-exclusive` - run all migrations up to and excluding version

  """

  @impl true
  def run(args, migrator \\ &Ecto.Migrator.run/4) do
    repos = Mix.Ecto.Tenant.parse_repo(args)
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)
    opts = Keyword.merge(@default_opts, opts)

    opts =
      if opts[:to] || opts[:to_exclusive] || opts[:step] || opts[:all],
        do: opts,
        else: Keyword.put(opts, :all, true)

    opts =
      if opts[:quiet],
        do: Keyword.merge(opts, log: false, log_migrations_sql: false, log_migrator_sql: false),
        else: opts

    if log_level = opts[:log_level] do
      Logger.configure(level: String.to_existing_atom(log_level))
    end

    # Start ecto_sql explicitly before as we don't need
    # to restart those apps if migrated.
    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    for repo <- repos do
      ensure_repo(repo, args)
      paths = ensure_migrations_paths(repo, opts)
      sources = Mix.Ecto.Tenant.migration_sources(paths)
      pool = repo.config()[:pool]

      Mix.Ecto.Tenant.start_otp_app(repo)

      tenants = Mix.Ecto.Tenant.tenants_from_opts(repo, opts)
      Mix.Ecto.Tenant.start_all_repos(tenants, pool_size: opts[:concurrency] + 1)

      Task.async_stream(tenants, fn tenant ->
        create_tenant(tenant)

        repo.set_tenant(tenant.name)

        opts = Keyword.merge(opts,
          dynamic_repo: tenant.dynamic_repo,
          prefix: tenant.prefix
        )

        f = if Code.ensure_loaded?(pool) and function_exported?(pool, :unboxed_run, 2) do
          &pool.unboxed_run(&1, fn -> migrator.(&1, sources, :up, opts) end)
        else
          &migrator.(&1, sources, :up, opts)
        end

        f.(tenant.repo)
      end)
      |> Stream.run()

      Mix.Ecto.Tenant.stop_all_repos(tenants)
    end

    :ok
  end

  defp create_tenant(tenant) do
    sql = "CREATE SCHEMA IF NOT EXISTS #{tenant.prefix}"
    result = Ecto.Adapters.SQL.query!(tenant.dynamic_repo, sql, [], log: false)
    tenant_name = Mix.Ecto.Tenant.display_name(tenant)

    case result.messages do
      [] -> :ok
      [%{code: "42P06"}] -> :ok
      [%{message: message}] -> Mix.raise("#{tenant_name} couldn't be created: #{message}")
    end
  end

end
