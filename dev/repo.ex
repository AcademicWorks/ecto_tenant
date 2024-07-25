defmodule Repo do
  use Ecto.Repo, otp_app: :ecto_tenant, adapter: Ecto.Adapters.Postgres
  use Ecto.Tenant, otp_app: :ecto_tenant

  @impl Ecto.Tenant
  def tenants do
    Application.get_env(@otp_app, __MODULE__, [])
    |> Keyword.get(:tenants)
  end

  @impl Ecto.Tenant
  def repos do
    Application.get_env(@otp_app, __MODULE__, [])
    |> Keyword.get(:repos)
  end

  @impl Ecto.Tenant
  def tenant_config(name) do
    tenants()
    |> Enum.find(& &1[:name] == name)
  end

  @impl Ecto.Tenant
  def repo_config(name) do
    repos()
    |> Enum.find(& &1[:name] == name)
    |> Keyword.merge(config())
    |> Keyword.delete(:tenants)
    |> Keyword.delete(:repos)
  end
end
