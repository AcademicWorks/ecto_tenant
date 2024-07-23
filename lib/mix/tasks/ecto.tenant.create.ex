defmodule Mix.Tasks.Ecto.Tenant.Create do
  use Mix.Task

  @shortdoc "Creates the multitenanted repository storage"

  @switches [
    quiet: :boolean,
    repo: [:string, :keep],
    no_compile: :boolean,
    no_deps_check: :boolean
  ]

  @aliases [
    r: :repo,
    q: :quiet
  ]

  @impl Mix.Task

  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    Mix.Ecto.Tenant.parse_repo(args)
    |> Enum.each(fn repo ->
      Enum.reduce(repo.tenants(), MapSet.new(), fn tenant, seen ->
        dyn_repo = Mix.Ecto.Tenant.dyn_repo(repo, tenant)

        if dyn_repo not in seen do
          create_repo(repo, dyn_repo, args, opts)
        end

        Mix.Ecto.Tenant.with_repo(repo, tenant, fn _->
          create_tenant(repo, dyn_repo, tenant, opts)
        end)

        MapSet.put(seen, dyn_repo)
      end)
    end)
  end

  defp create_repo(repo, dyn_repo, args, opts) do
    import Mix.Ecto

    config = repo.repo_config(dyn_repo)

    ensure_repo(repo, args)

    ensure_implements(
      repo.__adapter__(),
      Ecto.Adapter.Storage,
      "create storage for #{inspect(repo)}"
    )

    repo_name = Mix.Ecto.Tenant.repo_display_name(repo, dyn_repo)

    case repo.__adapter__().storage_up(config) do
      :ok ->
        unless opts[:quiet] do
          Mix.shell().info("The database for #{repo_name} has been created")
        end

      {:error, :already_up} ->
        unless opts[:quiet] do
          Mix.shell().info("The database for #{repo_name} has already been created")
        end

      {:error, term} when is_binary(term) ->
        Mix.raise("The database for #{repo_name} couldn't be created: #{term}")

      {:error, term} ->
        Mix.raise("The database for #{repo_name} couldn't be created: #{inspect(term)}")
    end
  end

  defp create_tenant(_repo, dyn_repo, tenant, opts) do
    sql = "CREATE SCHEMA IF NOT EXISTS #{tenant[:prefix]}"
    result = Ecto.Adapters.SQL.query!(dyn_repo, sql, [], log: false)

    tenant_name = Mix.Ecto.Tenant.tenant_display_name(tenant)

    case result.messages do
      [] ->
        unless opts[:quiet] do
          Mix.shell().info("#{tenant_name} has been created")
        end

      [%{code: "42P06"}] ->
        unless opts[:quiet] do
          Mix.shell().info("#{tenant_name} has already been created")
        end

      [%{message: message}] ->
        Mix.raise("#{tenant_name} couldn't be created: #{message}")
    end
  end

end
