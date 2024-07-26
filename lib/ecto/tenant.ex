defmodule Ecto.Tenant do

  @callback tenants :: [Keyword.t]
  @callback tenant_config(name :: String.t) :: Keyword.t
  @callback repos :: [Keyword.t]
  @callback repo_config(name :: atom) :: Keyword.t

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour Ecto.Tenant
      @otp_app unquote(opts[:otp_app])

      @impl true
      def tenants do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:tenants)
      end

      @impl true
      def repos do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:repos)
      end

      @impl true
      def tenant_config(name) do
        tenants()
        |> Enum.find(& &1[:name] == name)
      end

      @impl true
      def repo_config(name) do
        repos()
        |> Enum.find(& &1[:name] == name)
        |> Keyword.merge(config())
        |> Keyword.delete(:tenants)
        |> Keyword.delete(:repos)
      end
    end
  end

end
