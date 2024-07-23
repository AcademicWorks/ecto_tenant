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

    Mix.Tenant.parse_repo(args)
    |> Enum.each(fn repo ->
      Enum.reduce(repo.tenants(), MapSet.new(), fn tenant, seen ->
        dyn_repo = tenant[:repo] || repo

        if dyn_repo not in seen do
          create_repo(repo, dyn_repo, args, opts)
          start_repo(repo, dyn_repo)
        end

        create_tenant(repo, tenant, opts)

        MapSet.put(seen, dyn_repo)
      end)
    end)
  end

  defp create_repo(repo, dyn_repo, args, opts) do
    import Mix.Ecto

    repo.put_dynamic_repo(dyn_repo)

    ensure_repo(repo, args)

    ensure_implements(
      repo.__adapter__(),
      Ecto.Adapter.Storage,
      "create storage for #{inspect(repo)}"
    )

    case repo.__adapter__().storage_up(repo.config()) do
      :ok ->
        unless opts[:quiet] do
          Mix.shell().info("The database for #{inspect(repo)} has been created")
        end

      {:error, :already_up} ->
        unless opts[:quiet] do
          Mix.shell().info("The database for #{inspect(repo)} has already been created")
        end

      {:error, term} when is_binary(term) ->
        Mix.raise("The database for #{inspect(repo)} couldn't be created: #{term}")

      {:error, term} ->
        Mix.raise("The database for #{inspect(repo)} couldn't be created: #{inspect(term)}")
    end
  end

  defp create_tenant(repo, tenant, opts) do
    sql = "CREATE SCHEMA IF NOT EXISTS #{tenant[:prefix]}"

    result = repo.get_dynamic_repo()
    |> Ecto.Adapters.SQL.query!(sql, [], log: false)

    case result.messages do
      [] ->
        unless opts[:quiet] do
          Mix.shell().info("Schema #{inspect(tenant[:prefix])} has been created")
        end

      [%{code: "42P06"}] ->
        unless opts[:quiet] do
          Mix.shell().info("Schema #{inspect(tenant[:prefix])} has already been created")
        end

      [%{message: message}] ->
        Mix.raise("Schema #{inspect(tenant[:prefix])} couldn't be created: #{message}")
    end
  end

  def start_repo(repo, dyn_repo) do
    Enum.find(repo.repos(), & &1[:name] == dyn_repo)
    |> repo.start_link()
  end

end
