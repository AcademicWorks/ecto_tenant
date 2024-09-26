defmodule Ecto.Tenant do
  defstruct [:name, :repo, :dynamic_repo, :prefix]

  defmodule RepoSpec do
    defstruct [:name, :repo, :config]
  end

  @type tenant_name :: String.t
  @type repo_name :: atom

  @callback tenant_configs :: [Keyword.t]
  @callback tenant_config(tenant_name) :: Keyword.t
  @callback dynamic_repo_configs :: [Keyword.t]
  @callback dynamic_repo_config(repo_name) :: Keyword.t
  @callback set_tenant(tenant_name) :: {:ok, tenant_name} | {:error, String.t}
  @callback get_tenant() :: tenant_name | :undefined

  defmacro __using__(opts \\ []) do
    quote do

      use Ecto.Tenant.Supervisor, repo: __MODULE__

      @otp_app unquote(opts[:otp_app])
      @behaviour Ecto.Tenant
      @current_tenant_key {Ecto.Tenant, __MODULE__}

      def tenant_configs do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:tenants, [])
      end

      defoverridable(tenant_configs: 0)

      def tenant_config(name) do
        Enum.find(tenant_configs(), & &1[:name] == name)
      end

      defoverridable(tenant_config: 1)

      def dynamic_repo_configs do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:dynamic_repos, [])
      end

      defoverridable(dynamic_repo_configs: 0)

      def dynamic_repo_config(name) do
        Enum.find(dynamic_repo_configs(), & &1[:name] == name)
      end

      defoverridable(dynamic_repo_config: 1)

      def set_tenant(name) do
        Process.put(@current_tenant_key, name)
      end

      def get_tenant() do
        case Process.get(@current_tenant_key, :undefined) do
          :undefined ->
            Process.get(:"$callers", [])
            |> Enum.find_value(fn pid ->
              case Process.info(pid, :dictionary) do
                {:dictionary, dictionary} ->
                  Enum.find_value(dictionary, fn
                    {@current_tenant_key, name} -> name
                    _ -> false
                  end)
                _ -> false
              end
            end)

          tenant -> tenant
        end
      end

      def default_options(_) do
        config = get_tenant() |> tenant_config()
        [prefix: config[:prefix]]
      end

      defoverridable [get_dynamic_repo: 0]

      def get_dynamic_repo() do
        config = get_tenant() |> tenant_config()
        config[:dynamic_repo] || __MODULE__
      end

    end
  end

end
