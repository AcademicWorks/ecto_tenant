defmodule Ecto.Tenant do
  defstruct [:name, :repo, :dynamic_repo, :prefix]

  defmodule RepoSpec do
    defstruct [:name, :repo, :config]
  end

  @callback tenant_configs :: [Keyword.t]

  defmacro __using__(opts \\ []) do
    quote do

      @otp_app unquote(opts[:otp_app])
      @behaviour Ecto.Tenant

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

    end
  end

end
