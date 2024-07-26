defmodule Ecto.Tenant do

  @callback tenants :: [Keyword.t]
  @callback tenant_config(name :: String.t) :: Keyword.t
  @callback repos :: [Keyword.t]
  @callback repo_config(name :: atom) :: Keyword.t
  @callback set_tenant(name :: String.t) :: {:ok, String.t} | {:error, String.t}
  @callback current_tenant() :: String.t | :undefined

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour Ecto.Tenant
      @otp_app unquote(opts[:otp_app])
      @current_tenant_key String.to_atom("#{inspect __MODULE__}:current")

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

      @impl true
      def set_tenant(name) do
        case tenant_config(name) do
          nil -> {:error, "Tenant not found"}
          tenant ->
            put_dynamic_repo(tenant[:repo])
            Process.put(@current_tenant_key, tenant[:name])
            {:ok, name}
        end
      end

      @impl true
      def current_tenant() do
        Process.get(@current_tenant_key, :undefined)
      end

      def default_options(_) do
        tenant = current_tenant() |> tenant_config()

        case tenant do
          nil -> []
          tenant -> [prefix: tenant[:prefix]]
        end
      end
    end
  end

end
