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
      Mix.Ecto.Tenant.all_repo_specs(repo)
      |> Enum.each(fn repo_spec ->
        create_repo(repo_spec, args, opts)
      end)

      Mix.Ecto.Tenant.all_tenants(repo)
      |> Enum.each(fn tenant ->
        Mix.Ecto.Tenant.start_repo(tenant)
        create_tenant(tenant, opts)
      end)

      # repo.repos()
      # |> Enum.each(fn repo_config ->
      #   create_repo(repo, repo_config[:name] || repo, args, opts)
      # end)

      # repo.tenants()
      # |> Enum.each(fn tenant ->
      #   Mix.Ecto.Tenant.with_repo(repo, tenant, fn _->
      #     create_tenant(repo, tenant, opts)
      #   end)
      # end)
    end)
  end

  defp create_repo(spec, args, opts) do
    import Mix.Ecto

    %{
      repo: repo,
      config: config
    } = spec

    ensure_repo(repo, args)

    ensure_implements(
      repo.__adapter__(),
      Ecto.Adapter.Storage,
      "create storage for #{inspect(repo)}"
    )

    repo_name = Mix.Ecto.Tenant.display_name(spec)

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

  defp create_tenant(tenant, opts) do
    sql = "CREATE SCHEMA IF NOT EXISTS #{tenant.prefix}"
    result = Ecto.Adapters.SQL.query!(tenant.dynamic_repo, sql, [], log: false)

    tenant_name = Mix.Ecto.Tenant.display_name(tenant)

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
