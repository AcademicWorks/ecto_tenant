defmodule Ecto.Tenant do
  defstruct [:name, :repo, :dynamic_repo, :prefix]

  defmodule RepoSpec do
    defstruct [:name, :repo, :config]
  end

  @callback tenant_configs :: [Keyword.t]
  @callback dynamic_repo_configs :: [Keyword.t]
  @callback set_tenant(name :: String.t) :: {:ok, String.t} | {:error, String.t}
  @callback get_tenant() :: String.t | :undefined

  defmacro __using__(opts \\ []) do
    quote do

      @otp_app unquote(opts[:otp_app])
      @behaviour Ecto.Tenant
      @current_tenant_key String.to_atom("#{inspect __MODULE__}:current")

      def tenant_configs do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:tenants, [])
      end

      def tenant_config(name) do
        Enum.find(tenant_configs(), & &1[:name] == name)
      end

      def dynamic_repo_configs do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:dynamic_repos, [])
      end

      def dynamic_repo_config(name) do
        Enum.find(dynamic_repo_configs(), & &1[:name] == name)
      end

      def set_tenant(nil) do
        put_dynamic_repo(nil)
        Process.put(@current_tenant_key, nil)
        {:ok, nil}
      end
      def set_tenant(name) do
        case tenant_config(name) do
          nil -> {:error, "Tenant not found"}
          tenant ->
            put_dynamic_repo(tenant[:dynamic_repo])
            Process.put(@current_tenant_key, tenant[:name])
            {:ok, name}
        end
      end

      def get_tenant() do
        case Process.get(@current_tenant_key, :undefined) do
          :undefined ->
            Process.get(:"$callers", [])
            |> Enum.find_value(fn pid ->
              {:dictionary, dictionary} = Process.info(pid, :dictionary)
              case Keyword.get(dictionary, @current_tenant_key, :undefined) do
                :undefined -> false
                tenant -> tenant
              end
            end)
          tenant -> tenant
        end
      end

      def default_options(_) do
        tenant = get_tenant() |> tenant_config()

        case tenant do
          nil -> []
          tenant -> [prefix: tenant[:prefix]]
        end
      end

      defoverridable [get_dynamic_repo: 0]
      def get_dynamic_repo() do
        case Process.get({__MODULE__, :dynamic_repo}, :undefined) do
          :undefined ->
            Process.get(:"$callers", [])
            |> Enum.find_value(fn pid ->
              {:dictionary, dictionary} = Process.info(pid, :dictionary)

              case Enum.find(dictionary, fn {key, _} -> key == {__MODULE__, :dynamic_repo} end) do
                nil -> false
                {_, repo} -> repo
              end
            end)
          repo -> repo
        end
      end

    end
  end

end
