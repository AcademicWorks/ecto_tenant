defmodule Mix.Tenant do

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

end
