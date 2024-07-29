defmodule Mix.Tasks.Ecto.Tenant.Load do
  use Mix.Task
  import Mix.Ecto
  import Mix.EctoSQL

  @shortdoc "Loads previously dumped database structure"
  @default_opts [force: false, quiet: false, concurrency: 10]

  @aliases [
    d: :dump_path,
    f: :force,
    q: :quiet,
    r: :repo,
    t: :tenant,
    c: :concurrency
  ]

  @switches [
    dump_path: :string,
    force: :boolean,
    quiet: :boolean,
    repo: [:string, :keep],
    tenant: [:string, :keep],
    concurrency: :integer,
    no_compile: :boolean,
    no_deps_check: :boolean,
    skip_if_loaded: :boolean
  ]

  @moduledoc """
  Loads the current environment's database structure for the
  given repository from a previously dumped structure file.

  The repository must be set under `:ecto_repos` in the
  current app configuration or given via the `-r` option.

  This task needs some shell utility to be present on the machine
  running the task.

   Database   | Utility needed
   :--------- | :-------------
   PostgreSQL | psql
   MySQL      | mysql

  ## Example

      $ mix ecto.load

  ## Command line options

    * `-r`, `--repo` - the repo to load the structure info into
    * `-d`, `--dump-path` - the path of the dump file to load from
    * `-q`, `--quiet` - run the command quietly
    * `-f`, `--force` - do not ask for confirmation when loading data.
      Configuration is asked only when `:start_permanent` is set to true
      (typically in production)
    * `--no-compile` - does not compile applications before loading
    * `--no-deps-check` - does not check dependencies before loading
    * `--skip-if-loaded` - does not load the dump file if the repo has the migrations table up

  """

  @impl true
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)
    opts = Keyword.merge(@default_opts, opts)
    opts = if opts[:quiet], do: Keyword.put(opts, :log, false), else: opts

    Mix.Ecto.Tenant.parse_repo(args)
    |> Enum.each(fn repo ->
      ensure_repo(repo, args)

      ensure_implements(
        repo.__adapter__(),
        Ecto.Adapter.Structure,
        "load structure for #{inspect(repo)}"
      )

      {migration_repo, source} =
        Ecto.Migration.SchemaMigration.get_repo_and_source(repo, repo.config())

      if migration_repo != repo do
        Mix.raise("migration_repo not supported at this time")
      end

      tenants = Mix.Ecto.Tenant.tenants_from_opts(repo, opts)

      if Enum.count(tenants) > 1 && opts[:dump_path] do
        Mix.raise("--dump-path only works when loading a single tenant")
      end

      Mix.Ecto.Tenant.start_all_repos(tenants)

      if not (skip_safety_warnings?() or opts[:force]) do
        if opts[:skip_if_loaded] do
          confirm_load(repo)
        else
          warn_about_loaded_tenants(repo, tenants, source)
        end
      end

      Task.async_stream(tenants, fn tenant ->
        dump_path = Mix.Ecto.Tenant.dump_path(tenant, opts)
        if not File.exists?(dump_path) do
          Mix.shell().info("[WARNING] The structure for tenant #{inspect tenant.name} does not exist at #{dump_path}")
        else
          opts = Keyword.merge(opts,
            dump_path: dump_path
          )
          load_structure(tenant, opts)
        end
      end, max_concurrency: opts[:concurrency], timeout: :infinity)
      |> Stream.run()
    end)
  end

  defp warn_about_loaded_tenants(repo, tenants, source) do
    loaded = Enum.filter(tenants, fn tenant ->
      table_exists?(tenant, source)
    end)
    |> Enum.count()

    if loaded > 0 do
      Mix.shell().yes?("""
      It looks like structure was already loaded for #{loaded} tenant(s). Any attempt to load again might fail.
      Are you sure you want to proceed?
      """)
    else
      confirm_load(repo)
    end
  end

  defp table_exists?(tenant, table) do
    {sql, params} = case tenant.repo.__adapter__() do
      Ecto.Adapters.Postgres -> {
        "SELECT true FROM information_schema.tables WHERE table_name = $1 AND table_schema = $2 LIMIT 1",
        [table, tenant.prefix]
      }
    end

    result = Ecto.Adapters.SQL.query!(tenant.dynamic_repo, sql, params, log: false)

    result.num_rows > 0
  end

  # defp drop_schema(tenant) do
  #   sql = "DROP SCHEMA IF EXISTS #{tenant.prefix} CASCADE"
  #   result = Ecto.Adapters.SQL.query!(tenant.dynamic_repo, sql, [], log: false)
  # end

  defp skip_safety_warnings? do
    Mix.Project.config()[:start_permanent] != true
  end

  defp confirm_load(repo) do
    Mix.shell().yes?(
      "Are you sure you want to load a new structure for tenants in #{inspect(repo)}? Any existing data in this repo may be lost."
    )
  end

  defp load_structure(tenant, opts) do
    %{repo: repo, config: config} = Mix.Ecto.Tenant.fetch_repo_spec!(tenant)
    config = Keyword.merge(config, opts)
    start_time = System.system_time()

    case repo.__adapter__().structure_load(source_repo_priv(repo), config) do
      {:ok, location} ->
        unless opts[:quiet] do
          elapsed =
            System.convert_time_unit(System.system_time() - start_time, :native, :microsecond)

          Mix.shell().info(
            "The structure for #{inspect(repo)} has been loaded from #{location} in #{format_time(elapsed)}"
          )
        end

      {:error, term} when is_binary(term) ->
        Mix.raise("The structure for #{inspect(repo)} couldn't be loaded: #{term}")

      {:error, term} ->
        Mix.raise("The structure for #{inspect(repo)} couldn't be loaded: #{inspect(term)}")
    end
  end

  defp format_time(microsec) when microsec < 1_000, do: "#{microsec} μs"
  defp format_time(microsec) when microsec < 1_000_000, do: "#{div(microsec, 1_000)} ms"
  defp format_time(microsec), do: "#{Float.round(microsec / 1_000_000.0)} s"
end
