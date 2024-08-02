defmodule Mix.Ecto.Tenant do

  @doc """
  Parses the repository option from the given command line args list.

  If no repo option is given, it is retrieved from the application environment.
  """
  @spec parse_repo([term]) :: [Ecto.Repo.t]
  @ecto_tenant_repos_key :ecto_tenant_repos

  def parse_repo(args) do
    parse_repo(args, [])
  end

  defp parse_repo([key, value|t], acc) when key in ~w(--repo -r) do
    parse_repo t, [Module.concat([value])|acc]
  end

  defp parse_repo([_|t], acc) do
    parse_repo t, acc
  end

  defp parse_repo([], []) do
    apps =
      if apps_paths = Mix.Project.apps_paths() do
        Enum.filter(Mix.Project.deps_apps(), &is_map_key(apps_paths, &1))
      else
        [Mix.Project.config()[:app]]
      end

    apps
    |> Enum.flat_map(fn app ->
      Application.load(app)
      Application.get_env(app, @ecto_tenant_repos_key, [])
    end)
    |> Enum.uniq()
    |> case do
      [] ->
        Mix.shell().error """
        warning: could not find Ecto repos in any of the apps: #{inspect apps}.

        You can avoid this warning by passing the -r flag or by setting the
        repositories managed by those applications in your config/config.exs:

            config #{inspect hd(apps)}, ecto_repos: [...]
        """
        []
      repos ->
        repos
    end
  end

  defp parse_repo([], acc) do
    Enum.reverse(acc)
  end

  def tenants_from_opts(repo, opts) do
    case Keyword.get_values(opts, :tenant) do
      [] -> all_tenants(repo)
      names ->
        tenant_by_name = all_tenants(repo)
        |> Map.new(&{&1.name, &1})

        Enum.map(names, &Map.fetch!(tenant_by_name, &1))
    end
  end

  def display_name(%Ecto.Tenant.RepoSpec{} = spec) do
    if spec.repo == spec.name do
      inspect(spec.repo)
    else
      "#{inspect spec.repo} #{inspect spec.name}"
    end
  end

  def display_name(%Ecto.Tenant{} = tenant) do
    "Tenant #{inspect tenant.name} with schema #{inspect tenant.prefix}"
  end

  def all_tenants(repo) do
    repo.tenant_configs()
    |> Enum.map(fn config ->
      %Ecto.Tenant{
        name: Keyword.fetch!(config, :name),
        repo: repo,
        dynamic_repo: config[:dynamic_repo] || repo,
        prefix: config[:prefix]
      }
    end)
  end

  def all_repo_specs(repo) do
    base_config = repo.config()
    |> Keyword.drop([:tenants, :dynamic_repos])

    specs = repo.dynamic_repo_configs()
    |> Enum.map(fn config ->
      %Ecto.Tenant.RepoSpec{
        repo: repo,
        name: Keyword.fetch!(config, :name),
        config: Keyword.merge(base_config, config)
      }
    end)

    if Keyword.has_key?(base_config, :database) do
      spec = %Ecto.Tenant.RepoSpec{
        repo: repo,
        name: repo,
        config: base_config
      }
      [spec | specs]
    else
      specs
    end
  end

  def all_dynamic_repos(repo) do
    base_config = repo.config()
    |> Keyword.drop([:tenants, :dynamic_repos])

    repo.dynamic_repo_configs()
    |> Enum.map(fn config ->
      %Ecto.Tenant.RepoSpec{
        name: Keyword.fetch!(config, :name),
        repo: repo,
        config: Keyword.merge(base_config, config)
      }
    end)
  end

  def fetch_dynamic_repo!(repo, name) do
    all_dynamic_repos(repo)
    |> Enum.find(& &1.name == name)
    || raise ArgumentError, "Dynamic repo #{inspect name} for #{inspect repo} not found"
  end

  def fetch_repo_spec!(%Ecto.Tenant{} = tenant) do
    fetch_repo_spec!(tenant.repo, tenant.dynamic_repo)
  end

  def fetch_repo_spec!(repo, name) do
    all_repo_specs(repo)
    |> Enum.find(& &1.name == name)
    || raise ArgumentError, "Repo spec for #{inspect name} not found in #{inspect repo}"
  end

  def tenant_configs(repo) do
    repo.tenant_configs()
    |> Enum.map(fn config ->
      Keyword.put_new(config, :repo, repo)
    end)
  end

  def dyn_repo(repo, tenant) do
    tenant[:repo] || repo
  end

  def start_otp_app(repo) do
    otp_app = repo.config()[:otp_app]
    Application.ensure_all_started(otp_app, :temporary)
  end

  def start_repo(spec_or_tenant, opts \\ [])

  def start_repo(%Ecto.Tenant.RepoSpec{} = spec, opts) do
    %{repo: repo} = spec

    config = repo.config()
    apps = [:ecto_sql | config[:start_apps_before_migration] || []]

    Enum.each(apps, fn app ->
      {:ok, _} = Application.ensure_all_started(app, :temporary)
    end)

    {:ok, _} = repo.__adapter__().ensure_all_started(config, :temporary)

    config = Keyword.merge(spec.config, opts)

    case repo.start_link(config) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  def start_repo(%Ecto.Tenant{} = tenant, opts) do
    fetch_repo_spec!(tenant)
    |> start_repo(opts)
  end

  def start_all_repos(tenants, opts \\ []) do
    repo = List.first(tenants)
    |> Map.get(:repo)

    Stream.map(tenants, & &1.dynamic_repo)
    |> Enum.uniq()
    |> Enum.each(fn dyn_repo ->
      :ok = Mix.Ecto.Tenant.fetch_repo_spec!(repo, dyn_repo)
      |> Mix.Ecto.Tenant.start_repo(opts)
    end)
  end

  def stop_all_repos(tenants) do
    Stream.map(tenants, & &1.dynamic_repo)
    |> Enum.uniq()
    |> Enum.each(fn dyn_repo -> Supervisor.stop(dyn_repo) end)
  end

  def with_repo(repo, tenant, f) do
    dyn_repo = dyn_repo(repo, tenant)
    config = repo.repo_config(dyn_repo)
    apps = [:ecto_sql | config[:start_apps_before_migration] || []]

    Enum.each(apps, fn app ->
      {:ok, started} = Application.ensure_all_started(app, :temporary)
      started
    end)

    # mode = Keyword.get(opts, :mode, :permanent)
    mode = :permanent

    {:ok, _repo_started} = repo.__adapter__().ensure_all_started(config, mode)

    case repo.start_link(config) do
      {:ok, _pid} -> {:ok, f.(repo), apps}
      {:error, {:already_started, _pid}} -> {:ok, f.(repo), apps}
      error -> error
    end
  end

  def migration_sources(paths) do
    Enum.flat_map(paths, fn path ->
      Path.wildcard("#{path}/*.exs")
      |> Enum.map(fn path ->
        [version | _] = Path.basename(path)
        |> String.split("_", parts: 2)

        version = case Integer.parse(version) do
          {version, ""} -> version
          _error -> "file #{Path.relative_to_cwd(path)} does not have an integer version"
        end

        mod = path
        |> Code.compile_file()
        |> Enum.map(&elem(&1, 0))
        |> Enum.find(&migration?/1)

        if mod do
          {version, mod}
        else
          raise Ecto.MigrationError,
            "file #{Path.relative_to_cwd(path)} does not define an Ecto.Migration"
        end
      end)
    end)
  end

  defp migration?(mod) do
    Code.ensure_loaded?(mod) and function_exported?(mod, :__migration__, 0)
  end

  def dump_path(tenant, opts) do
    opts[:dump_path] || Path.join([
      Mix.EctoSQL.source_repo_priv(tenant.repo),
      "structure",
      "#{tenant.name}.sql"
    ])
  end

end
