defmodule Ecto.Tenant do

  @callback tenants :: [Keyword.t]
  @callback tenant_config(name :: String.t) :: Keyword.t
  @callback repos :: [Keyword.t]
  @callback repo_config(name :: atom) :: Keyword.t

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour Ecto.Tenant
      @otp_app unquote(opts[:otp_app])
    end
  end

end
