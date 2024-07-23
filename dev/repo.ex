defmodule Repo do
  use Ecto.Repo, otp_app: :ecto_tenant, adapter: Ecto.Adapters.Postgres
  use Ecto.Tenant, otp_app: :ecto_tenant

end
