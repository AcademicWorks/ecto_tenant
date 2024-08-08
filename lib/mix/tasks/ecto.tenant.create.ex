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
      Mix.Ecto.ensure_repo(repo, args)

      Mix.Ecto.Tenant.all_repo_specs(repo)
      |> Enum.each(fn repo_spec ->
        Mix.Ecto.Tenant.start_otp_app(repo)
        create_repo(repo_spec, args, opts)
      end)
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

end
