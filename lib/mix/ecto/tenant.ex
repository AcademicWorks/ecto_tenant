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

  def repo_display_name(repo, dyn_repo) do
    if repo == dyn_repo do
      inspect(repo)
    else
      "#{inspect repo} #{inspect dyn_repo}"
    end
  end

  def tenant_display_name(tenant) do
    "Tenant #{inspect tenant[:name]} with schema #{inspect tenant[:prefix]}"
  end

  def dyn_repo(repo, tenant) do
    tenant[:repo] || repo
  end

  def with_repo(repo, tenant, f) do
    dyn_repo = dyn_repo(repo, tenant)
    config = repo.repo_config(dyn_repo)
    apps = config[:start_apps_before_migration] || []

    Enum.each(apps, fn app ->
      {:ok, started} = Application.ensure_all_started(app, :temporary)
      started
    end)

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

end
