defmodule Repo do
  use Ecto.Repo, otp_app: :ecto_tenant, adapter: Ecto.Adapters.Postgres
  use Ecto.Tenant, otp_app: :ecto_tenant

  def tenants do
    Application.get_env(@otp_app, __MODULE__, [])
    |> Keyword.get(:tenants)
  end

end
