defmodule Repo do
  use Ecto.Repo, otp_app: :ecto_tenant, adapter: Ecto.Adapters.Postgres
  use Ecto.Tenant, otp_app: :ecto_tenant

  def init(_context, config) do
    dyn_repo = get_dynamic_repo()

    dyn_config = if dyn_repo == __MODULE__ do
      config
    else
      Enum.find(config[:repos] || [], fn dyn_repo_config ->
        dyn_repo_config[:name] == dyn_repo
      end)
    end

    if !dyn_config do
      raise ArgumentError, "Tenant repo #{inspect dyn_repo} has not been defined"
    end

    config = Keyword.merge(config, dyn_config)
    |> Keyword.delete(:tenants)
    |> Keyword.delete(:repos)

    {:ok, config}
  end

  def repo_config(name) do
    Enum.find(repos(), & &1[:name] == name)
  end

  def start_tenant_repo(name) do
    start_link(repo_config(name))
  end

end
